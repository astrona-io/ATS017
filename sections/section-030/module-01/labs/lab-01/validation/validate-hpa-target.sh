#!/usr/bin/env bash
# Grading for ats-017-lab-030-01-01. Checks:
#   1. scout has a CPU request between 50m and 250m
#   2. the HPA still scales Deployment scout on CPU of type Utilization
#   3. the HPA reports a CPU utilisation and ScalingActive is True
#   4. under load from shuttle the HPA adds a replica to scout
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

to_millicores() {
  case "$1" in
    *m) echo "${1%m}" ;;
    "") echo 0 ;;
    *[!0-9]*) echo 0 ;;
    *) echo $(( $1 * 1000 )) ;;
  esac
}

# --- 1. the CPU request ------------------------------------------------------------
request=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
[ -n "$request" ] || fail "scout has no CPU request"
request_m=$(to_millicores "$request")
[ "$request_m" -ge 50 ] || fail "CPU request is ${request}, expected at least 50m"
[ "$request_m" -le 250 ] || fail "CPU request is ${request}, expected at most 250m"
echo "OK: scout has a CPU request of ${request}"

# --- 2. the HPA is still the same kind of HPA ---------------------------------------
kubectl -n "$NS" get hpa scout >/dev/null 2>&1 || fail "the HPA scout does not exist. Fix it, do not delete it"
target_kind=$(kubectl -n "$NS" get hpa scout -o jsonpath='{.spec.scaleTargetRef.kind}/{.spec.scaleTargetRef.name}')
[ "$target_kind" = "Deployment/scout" ] || fail "the HPA scales ${target_kind}, expected Deployment/scout"
metric=$(kubectl -n "$NS" get hpa scout -o jsonpath='{.spec.metrics[0].type}/{.spec.metrics[0].resource.name}/{.spec.metrics[0].resource.target.type}')
[ "$metric" = "Resource/cpu/Utilization" ] || fail "the HPA metric is ${metric}, expected Resource/cpu/Utilization"
echo "OK: the HPA scales Deployment/scout on CPU Utilization"

# --- 3. the target resolves ---------------------------------------------------------
kubectl -n "$NS" rollout status deploy/scout --timeout=180s >/dev/null 2>&1 || fail "scout rollout did not finish"
resolved=""
for _ in $(seq 1 60); do
  utilisation=$(kubectl -n "$NS" get hpa scout -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
  active=$(kubectl -n "$NS" get hpa scout -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}' 2>/dev/null)
  if [ -n "$utilisation" ] && [ "$active" = "True" ]; then resolved="yes"; break; fi
  sleep 5
done
[ -n "$resolved" ] || fail "the HPA still has no CPU utilisation (ScalingActive='${active:-unknown}'). Check kubectl describe hpa scout"
echo "OK: the HPA reads ${utilisation}% CPU utilisation"

# --- 4. behaviour: load from shuttle adds a replica ---------------------------------
kubectl -n "$NS" exec deploy/shuttle -- sh -c 'for i in 1 2 3 4; do timeout 170 curl -s -o /dev/null -X POST "http://scout/token?[1-5000000]" & done; wait' >/dev/null 2>&1 &
load_pid=$!

replicas=1
for _ in $(seq 1 45); do
  replicas=$(kubectl -n "$NS" get hpa scout -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
  [ "${replicas:-1}" -ge 2 ] && break
  sleep 5
done
kill "$load_pid" 2>/dev/null; wait "$load_pid" 2>/dev/null
[ "${replicas:-1}" -ge 2 ] || fail "the HPA still reports ${replicas:-1} replica after 3 minutes of load from shuttle"
echo "OK: the HPA scaled scout to ${replicas} replicas under load"

echo "PASS: the HPA reads the CPU target and scales scout up under load"
exit 0
