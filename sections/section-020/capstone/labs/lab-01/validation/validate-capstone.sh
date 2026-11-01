#!/usr/bin/env bash
# Grading for ats-017-capstone-020. Checks behaviour:
#   1. requests from outpost through the Gateway reach scout (/api) and bridge (/)
#   2. requests from outpost straight to the Services time out
#   3. DNS still works in starfleet
#   4. scout data survives pod replacement on a bound Retain volume
set -u

NS="starfleet"

fail() { echo "FAIL: $*"; exit 1; }

from_outpost() {  # $@ = curl args; prints the HTTP status code (000 on timeout)
  kubectl -n outpost exec deploy/shuttle -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@" 2>/dev/null
}

body_from_outpost() {
  kubectl -n outpost exec deploy/shuttle -- curl -s --max-time 5 "$@" 2>/dev/null
}

# --- 1. the Gateway ---------------------------------------------------------------
# The controller starts the proxy pod after the Gateway is created; wait up to 2 minutes.
programmed=""
for _ in $(seq 1 60); do
  programmed=$(kubectl -n "$NS" get gateway starfleet-gateway \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  [ "$programmed" = "True" ] && break
  sleep 2
done
[ "$programmed" = "True" ] || fail "Gateway starfleet-gateway is missing or not Programmed"
gateway=$(kubectl -n "$NS" get gateway starfleet-gateway -o jsonpath='{.status.addresses[0].value}')
[ -n "$gateway" ] || fail "Gateway starfleet-gateway has no address"
echo "OK: Gateway starfleet-gateway is Programmed at $gateway"

# Proxy and route programming can lag behind the status; retry for up to 90 s.
api_ok=""
for _ in $(seq 1 45); do
  if body_from_outpost "http://$gateway/api/info" | grep -q '"hostname": *"scout-'; then api_ok=yes; break; fi
  sleep 2
done
[ -n "$api_ok" ] || fail "GET /api/info through the Gateway did not return scout's answer. Check the HTTPRoute status and the NetworkPolicy"
echo "OK: GET /api/info through the Gateway reaches scout"

code=$(from_outpost "http://$gateway/")
[ "$code" = "200" ] || fail "GET / through the Gateway returned $code, expected 200 from bridge"
body_from_outpost "http://$gateway/" | grep -q "bridge front end" \
  || fail "GET / through the Gateway did not return bridge's page"
echo "OK: GET / through the Gateway reaches bridge"

# --- 2. other paths are closed ------------------------------------------------------
for target in scout bridge; do
  code=$(from_outpost "http://$target.$NS.svc")
  [ "$code" = "000" ] || fail "outpost reached $target directly (HTTP $code). Only the Gateway may reach it"
done
echo "OK: outpost cannot reach scout or bridge directly"

# --- 3. DNS still works ---------------------------------------------------------------
kubectl -n "$NS" exec deploy/shuttle -- nslookup scout.$NS.svc.cluster.local >/dev/null 2>&1 \
  || fail "DNS lookups fail inside $NS. Allow egress to kube-dns on port 53"
echo "OK: DNS works in $NS"

policy_types=$(kubectl -n "$NS" get networkpolicy \
  -o jsonpath='{range .items[*]}{.spec.policyTypes[*]}{"\n"}{end}')
echo "$policy_types" | grep -q Ingress || fail "no NetworkPolicy in $NS with policyType Ingress"
echo "$policy_types" | grep -q Egress  || fail "no NetworkPolicy in $NS with policyType Egress"
echo "OK: ingress and egress are both covered by policy"

# --- 4. storage -----------------------------------------------------------------------
phase=$(kubectl -n "$NS" get pvc scout-data -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$phase" = "Bound" ] || fail "claim scout-data is '${phase:-missing}', expected Bound"
class=$(kubectl -n "$NS" get pvc scout-data -o jsonpath='{.spec.storageClassName}')
[ "$class" = "standard-retain" ] || fail "scout-data uses class '$class', expected standard-retain"
volume=$(kubectl -n "$NS" get pvc scout-data -o jsonpath='{.spec.volumeName}')
policy=$(kubectl get pv "$volume" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')
[ "$policy" = "Retain" ] || fail "volume $volume has reclaim policy '$policy', expected Retain"
echo "OK: scout-data is Bound on a Retain volume"

claim=$(kubectl -n "$NS" get deploy scout \
  -o jsonpath='{.spec.template.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}')
[ "$claim" = "scout-data" ] || fail "scout does not use the claim scout-data"
mount=$(kubectl -n "$NS" get deploy scout \
  -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.mountPath=="/data")].name}')
[ -n "$mount" ] || fail "scout does not mount a volume at /data"

kubectl -n "$NS" rollout status deploy/scout --timeout=120s >/dev/null 2>&1 || fail "scout is not ready"
marker="grader-$(date +%s)"
old_pod=$(kubectl -n "$NS" get pod -l app=scout --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')
kubectl -n "$NS" exec "$old_pod" -- sh -c "echo $marker > /data/grader.txt" \
  || fail "could not write to /data in $old_pod"
kubectl -n "$NS" delete pod "$old_pod" --wait=true >/dev/null 2>&1
kubectl -n "$NS" rollout status deploy/scout --timeout=180s >/dev/null 2>&1 \
  || fail "scout did not become ready again after its pod was deleted"

new_pod=""
for _ in $(seq 1 30); do
  new_pod=$(kubectl -n "$NS" get pod -l app=scout --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [ -n "$new_pod" ] && [ "$new_pod" != "$old_pod" ] && break
  sleep 2
done
[ -n "$new_pod" ] && [ "$new_pod" != "$old_pod" ] || fail "no replacement scout pod found"
found=$(kubectl -n "$NS" exec "$new_pod" -- cat /data/grader.txt 2>/dev/null)
[ "$found" = "$marker" ] || fail "the file written before the pod was replaced is missing"
echo "OK: /data/grader.txt survived replacing $old_pod with $new_pod"

echo "PASS: gateway routes, policies hold and scout keeps its data on a Retain volume"
exit 0
