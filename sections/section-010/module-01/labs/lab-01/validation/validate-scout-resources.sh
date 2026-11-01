#!/usr/bin/env bash
# Grading for ats-017-lab-010-01-01. Checks:
#   1. scout keeps its --stress-memory load (the load is not removed)
#   2. the memory limit is between 128Mi and 256Mi and above the request
#   3. the pod is Ready, QoS Burstable, and does not restart for 40 seconds
#   4. shuttle gets HTTP 200 from the scout Service
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

to_mib() {
  case "$1" in
    *Mi) echo "${1%Mi}" ;;
    *Gi) echo $(( ${1%Gi} * 1024 )) ;;
    *) echo 0 ;;
  esac
}

# --- 1. the load stays -------------------------------------------------------------
cmd=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].command} {.spec.template.spec.containers[0].args}')
case "$cmd" in
  *--stress-memory=100*) echo "OK: scout still starts with --stress-memory=100" ;;
  *) fail "scout no longer starts with --stress-memory=100. Fix the limit, do not remove the load" ;;
esac

# --- 2. the limit and the request ---------------------------------------------------
limit=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')
request=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')
[ -n "$limit" ] || fail "scout has no memory limit"
limit_mib=$(to_mib "$limit"); request_mib=$(to_mib "$request")
[ "$limit_mib" -ge 128 ] || fail "memory limit is ${limit}, expected at least 128Mi (use Mi or Gi units)"
[ "$limit_mib" -le 256 ] || fail "memory limit is ${limit}, expected at most 256Mi"
[ "$request_mib" -gt 0 ] || fail "scout has no memory request in Mi or Gi"
[ "$request_mib" -lt "$limit_mib" ] || fail "memory request ${request} is not below the limit ${limit}"
echo "OK: memory request ${request}, limit ${limit}"

# --- 3. stable, Burstable -----------------------------------------------------------
kubectl -n "$NS" rollout status deploy/scout --timeout=120s >/dev/null 2>&1 || fail "scout rollout did not finish"
pod=$(kubectl -n "$NS" get pod -l app=scout --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$pod" ] || fail "no Running scout pod"
qos=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.qosClass}')
[ "$qos" = "Burstable" ] || fail "QoS class is ${qos}, expected Burstable"
echo "OK: pod $pod is $qos"

sleep 40
restarts=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].restartCount}')
ready=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].ready}')
[ "$restarts" = "0" ] || fail "pod $pod restarted ${restarts} times"
[ "$ready" = "true" ] || fail "pod $pod is not Ready"
echo "OK: pod $pod ran 40 seconds with 0 restarts"

# --- 4. behaviour --------------------------------------------------------------------
code=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s -o /dev/null -m 5 -w '%{http_code}' http://scout:9898/healthz 2>/dev/null)
[ "$code" = "200" ] || fail "shuttle got HTTP '${code:-no answer}' from scout:9898/healthz, expected 200"
echo "OK: shuttle gets HTTP 200 from scout"

echo "PASS: scout runs inside its limits with the Burstable QoS class"
exit 0
