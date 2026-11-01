#!/usr/bin/env bash
# Grading for ats-017-capstone-010. Checks:
#   1. scout: 4 Running pods, all Guaranteed
#   2. scout: 2 pods in each zone, set by a topology spread constraint
#   3. probe: 2 Running pods on the ssd node, set by required node affinity
#   4. node labels are unchanged
#   5. shuttle gets HTTP 200 from scout and probe
set -u

fail() { echo "FAIL: $*"; exit 1; }
ZONE_KEY='topology.kubernetes.io/zone'

zone_a_node=$(kubectl get nodes -l "$ZONE_KEY=zone-a" -o jsonpath='{.items[0].metadata.name}')
zone_b_node=$(kubectl get nodes -l "$ZONE_KEY=zone-b" -o jsonpath='{.items[0].metadata.name}')
[ -n "$zone_a_node" ] && [ -n "$zone_b_node" ] || fail "zone labels on the workers were changed"

# --- 4. labels -----------------------------------------------------------------------
ssd_nodes=$(kubectl get nodes -l disktype=ssd -o jsonpath='{.items[*].metadata.name}')
[ "$ssd_nodes" = "$zone_a_node" ] || fail "disktype=ssd must stay on the zone-a node only (found: ${ssd_nodes:-none}). Change probe, not the labels"
echo "OK: node labels unchanged"

# --- 1. scout resources ---------------------------------------------------------------
kubectl -n starfleet rollout status deploy/scout --timeout=240s >/dev/null 2>&1 || fail "scout rollout did not finish"
# Wait for pods of the old ReplicaSet to finish terminating.
for _ in $(seq 1 30); do
  pods=$(kubectl -n starfleet get pods -l app=scout --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.status.qosClass}|{.spec.nodeName}|{.metadata.deletionTimestamp}{"\n"}{end}' | grep '|$' | sed 's/|$//')
  [ "$(echo "$pods" | grep -c .)" -eq 4 ] && break
  sleep 2
done
count=$(echo "$pods" | grep -c .)
[ "$count" -eq 4 ] || fail "expected 4 Running scout pods, found $count"
not_guaranteed=$(echo "$pods" | grep -vc '^Guaranteed|')
[ "$not_guaranteed" -eq 0 ] || fail "$not_guaranteed scout pod(s) are not Guaranteed. Every request must equal its limit for CPU and memory"
echo "OK: 4 scout pods, all Guaranteed"

# --- 2. scout spread -------------------------------------------------------------------
on_a=$(echo "$pods" | grep -c "|${zone_a_node}$")
on_b=$(echo "$pods" | grep -c "|${zone_b_node}$")
[ "$on_a" -eq 2 ] && [ "$on_b" -eq 2 ] || fail "scout pods per zone: zone-a=$on_a zone-b=$on_b, expected 2 and 2"
tsc=$(kubectl -n starfleet get deploy scout -o jsonpath='{.spec.template.spec.topologySpreadConstraints[*].topologyKey}')
echo "$tsc" | grep -qx "$ZONE_KEY" || fail "scout has no topology spread constraint on $ZONE_KEY (found: ${tsc:-none})"
skew=$(kubectl -n starfleet get deploy scout -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].maxSkew}')
[ "$skew" = "1" ] || fail "maxSkew is ${skew:-unset}, expected 1"
echo "OK: scout spread 2 + 2 by a topology spread constraint with maxSkew 1"

# --- 3. probe ---------------------------------------------------------------------------
kubectl -n outpost rollout status deploy/probe --timeout=180s >/dev/null 2>&1 || fail "probe rollout did not finish"
for _ in $(seq 1 30); do
  nodes=$(kubectl -n outpost get pods -l app=probe --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.spec.nodeName}|{.metadata.deletionTimestamp}{"\n"}{end}' | grep '|$' | sed 's/|$//')
  [ "$(echo "$nodes" | grep -c .)" -eq 2 ] && break
  sleep 2
done
[ "$(echo "$nodes" | grep -c .)" -eq 2 ] || fail "expected 2 Running probe pods"
[ "$(echo "$nodes" | grep -vxc "$zone_a_node")" -eq 0 ] || fail "a probe pod runs outside the ssd node"
aff=$(kubectl -n outpost get deploy probe -o jsonpath='{.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[*].matchExpressions[*].key}')
echo "$aff" | grep -qx disktype || fail "probe must keep required node affinity on disktype"
echo "OK: 2 probe pods on the ssd node through required node affinity"

# --- 5. behaviour -----------------------------------------------------------------------
code=$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -m 5 -w '%{http_code}' http://scout:9898/healthz 2>/dev/null)
[ "$code" = "200" ] || fail "shuttle got HTTP '${code:-no answer}' from scout"
code=$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -m 5 -w '%{http_code}' http://probe.outpost:8080/status/200 2>/dev/null)
[ "$code" = "200" ] || fail "shuttle got HTTP '${code:-no answer}' from probe"
echo "OK: shuttle reaches scout and probe"

echo "PASS: scout is Guaranteed and spread, probe runs on the ssd node"
exit 0
