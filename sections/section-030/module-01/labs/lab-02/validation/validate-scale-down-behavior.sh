#!/usr/bin/env bash
# Grading for ats-017-lab-030-01-02. Checks:
#   1. behavior.scaleDown.stabilizationWindowSeconds is between 120 and 600
#   2. a Pods policy with value 1 or a Percent policy with value 25 or less, periodSeconds 30 or more
#   3. selectPolicy is not Disabled, the metric, min and max are unchanged, scaleUp is not slowed
#   4. under load scout reaches 3 replicas and keeps them for 45 seconds after the load stops
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }
hpa() { kubectl -n "$NS" get hpa scout -o jsonpath="$1" 2>/dev/null; }

kubectl -n "$NS" get hpa scout >/dev/null 2>&1 || fail "the HPA scout does not exist"

# --- 1. the stabilization window ----------------------------------------------------
window=$(hpa '{.spec.behavior.scaleDown.stabilizationWindowSeconds}')
[ -n "$window" ] || fail "behavior.scaleDown.stabilizationWindowSeconds is not set"
[ "$window" -ge 120 ] || fail "stabilizationWindowSeconds is ${window}, expected at least 120"
[ "$window" -le 600 ] || fail "stabilizationWindowSeconds is ${window}, expected at most 600"
echo "OK: scale-down stabilization window is ${window} seconds"

# --- 2. the policy ------------------------------------------------------------------
policy_ok=""
while read -r kind value period; do
  [ -n "$kind" ] || continue
  [ "${period:-0}" -ge 30 ] || continue
  if [ "$kind" = "Pods" ] && [ "$value" -eq 1 ]; then policy_ok="yes"; fi
  if [ "$kind" = "Percent" ] && [ "$value" -ge 1 ] && [ "$value" -le 25 ]; then policy_ok="yes"; fi
done < <(hpa '{range .spec.behavior.scaleDown.policies[*]}{.type} {.value} {.periodSeconds}{"\n"}{end}')
[ -n "$policy_ok" ] || fail "no scaleDown policy of type Pods with value 1 or Percent with value 25 or less and periodSeconds of at least 30"
echo "OK: a scaleDown policy limits the pace"

# --- 3. nothing else was broken -----------------------------------------------------
select_policy=$(hpa '{.spec.behavior.scaleDown.selectPolicy}')
[ "$select_policy" != "Disabled" ] || fail "scaleDown selectPolicy is Disabled. Slow the scale-down, do not turn it off"
metric=$(hpa '{.spec.metrics[0].type}/{.spec.metrics[0].resource.name}/{.spec.metrics[0].resource.target.type}/{.spec.metrics[0].resource.target.averageUtilization}')
[ "$metric" = "Resource/cpu/Utilization/50" ] || fail "the HPA metric is ${metric}, expected Resource/cpu/Utilization/50"
bounds=$(hpa '{.spec.minReplicas}-{.spec.maxReplicas}')
[ "$bounds" = "1-5" ] || fail "minReplicas-maxReplicas is ${bounds}, expected 1-5"
up_window=$(hpa '{.spec.behavior.scaleUp.stabilizationWindowSeconds}')
[ -z "$up_window" ] || [ "$up_window" = "0" ] || fail "scaleUp stabilizationWindowSeconds is ${up_window}, expected it to stay 0"
echo "OK: metric, bounds and scale-up are unchanged"

# --- 4. behaviour -------------------------------------------------------------------
for _ in $(seq 1 60); do
  active=$(hpa '{.status.conditions[?(@.type=="ScalingActive")].status}')
  [ "$active" = "True" ] && break
  sleep 3
done
kubectl -n "$NS" exec deploy/shuttle -- pkill curl >/dev/null 2>&1
kubectl -n "$NS" exec deploy/shuttle -- sh -c 'for i in 1 2 3 4; do timeout 240 curl -s -o /dev/null -X POST "http://scout/token?[1-5000000]" & done; wait' >/dev/null 2>&1 &
load_pid=$!

replicas=1
for _ in $(seq 1 48); do
  replicas=$(hpa '{.status.currentReplicas}')
  [ "${replicas:-1}" -ge 3 ] && break
  sleep 5
done
kill "$load_pid" 2>/dev/null; wait "$load_pid" 2>/dev/null
kubectl -n "$NS" exec deploy/shuttle -- pkill curl >/dev/null 2>&1
[ "${replicas:-1}" -ge 3 ] || fail "the HPA reached only ${replicas:-1} replicas under load, expected 3 or more"
peak="$replicas"
echo "OK: scout scaled up to ${peak} replicas under load"

echo "Load stopped. Waiting 45 seconds to check that the replicas stay."
sleep 45
after=$(hpa '{.status.currentReplicas}')
[ "${after:-0}" -ge "$peak" ] || fail "scout dropped from ${peak} to ${after} replicas within 45 seconds after the load stopped"
echo "OK: scout still has ${after} replicas 45 seconds after the load stopped"

echo "PASS: the HPA scales down slowly and still scales up under load"
exit 0
