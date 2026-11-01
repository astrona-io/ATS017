#!/usr/bin/env bash
# Grading for ats-017-lab-010-02-01. Checks:
#   1. the zone-b node still has the taint dedicated=outpost:NoSchedule
#   2. probe has a toleration for it and still selects zone-b
#   3. every probe pod is Running on the zone-b node (2 replicas)
#   4. no scout pod runs on the zone-b node
#   5. shuttle gets HTTP 200 from probe in outpost
set -u

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. the taint stays ------------------------------------------------------------
zone_b_node=$(kubectl get nodes -l topology.kubernetes.io/zone=zone-b -o jsonpath='{.items[0].metadata.name}')
[ -n "$zone_b_node" ] || fail "no node with zone label zone-b"
taint=$(kubectl get node "$zone_b_node" -o jsonpath='{range .spec.taints[*]}{.key}={.value}:{.effect}{"\n"}{end}' | grep -x 'dedicated=outpost:NoSchedule')
[ -n "$taint" ] || fail "node $zone_b_node lost the taint dedicated=outpost:NoSchedule. Add a toleration, do not remove the taint"
echo "OK: $zone_b_node still has the taint dedicated=outpost:NoSchedule"

# --- 2. toleration and selector ------------------------------------------------------
tol=$(kubectl -n outpost get deploy probe -o jsonpath='{range .spec.template.spec.tolerations[*]}{.key}|{.operator}|{.value}|{.effect}{"\n"}{end}')
echo "$tol" | grep -Eq '^dedicated\|(Equal\|outpost|Exists\|)\|(NoSchedule)?$' \
  || fail "probe has no toleration for dedicated=outpost:NoSchedule (found: ${tol:-none})"
zone=$(kubectl -n outpost get deploy probe -o jsonpath='{.spec.template.spec.nodeSelector.topology\.kubernetes\.io/zone}')
[ "$zone" = "zone-b" ] || fail "probe no longer selects zone-b"
echo "OK: probe tolerates the taint and still selects zone-b"

# --- 3. placement -------------------------------------------------------------------
kubectl -n outpost rollout status deploy/probe --timeout=120s >/dev/null 2>&1 || fail "probe rollout did not finish"
nodes=$(kubectl -n outpost get pods -l app=probe --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}')
count=$(echo "$nodes" | grep -c .)
[ "$count" -eq 2 ] || fail "expected 2 Running probe pods, found $count"
[ "$(echo "$nodes" | grep -vx "$zone_b_node" | grep -c .)" -eq 0 ] || fail "a probe pod runs outside $zone_b_node"
echo "OK: 2 probe pods Running on $zone_b_node"

# --- 4. scout stays off the dedicated node -------------------------------------------
on_b=$(kubectl -n starfleet get pods -l app=scout -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | grep -cx "$zone_b_node")
[ "$on_b" -eq 0 ] || fail "$on_b scout pod(s) run on the dedicated node"
echo "OK: scout pods stay off $zone_b_node"

# --- 5. behaviour ---------------------------------------------------------------------
code=$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -m 5 -w '%{http_code}' http://probe.outpost:8080/status/200 2>/dev/null)
[ "$code" = "200" ] || fail "shuttle got HTTP '${code:-no answer}' from probe.outpost:8080, expected 200"
echo "OK: shuttle gets HTTP 200 from probe"

echo "PASS: probe runs on the dedicated node and the taint is intact"
exit 0
