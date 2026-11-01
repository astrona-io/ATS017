#!/usr/bin/env bash
# Grading for ats-017-capstone-030. Checks:
#   1. scout requests 25m to 250m CPU and 24Mi to 256Mi memory, with a memory limit
#      at least the request and at most 512Mi; image unchanged
#   2. an autoscaling/v2 HPA scout scales Deployment/scout on CPU Utilization,
#      target 40 to 80, minReplicas 1, maxReplicas 3 to 6
#   3. behavior.scaleDown.stabilizationWindowSeconds is between 30 and 90
#   4. the HPA reads the CPU utilisation, adds a replica under load from shuttle,
#      and returns to one replica after the load stops
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; stop_load; exit 1; }
stop_load() { kubectl -n "$NS" exec deploy/shuttle -- pkill curl >/dev/null 2>&1; }
hpa() { kubectl -n "$NS" get hpa scout -o jsonpath="$1" 2>/dev/null; }
field() { kubectl -n "$NS" get deploy scout -o jsonpath="{.spec.template.spec.containers[0].$1}" 2>/dev/null; }

to_millicores() {
  case "$1" in
    *m) echo "${1%m}" ;;
    "") echo 0 ;;
    *[!0-9]*) echo 0 ;;
    *) echo $(( $1 * 1000 )) ;;
  esac
}
to_mebibytes() {
  case "$1" in
    *Gi) echo $(( ${1%Gi} * 1024 )) ;;
    *Mi) echo "${1%Mi}" ;;
    *Ki) echo $(( ${1%Ki} / 1024 )) ;;
    "") echo 0 ;;
    *[!0-9]*) echo 0 ;;
    *) echo $(( $1 / 1048576 )) ;;
  esac
}

# --- 1. the requests ----------------------------------------------------------------
kubectl -n "$NS" get deploy scout >/dev/null 2>&1 || fail "the Deployment scout does not exist"
image=$(field image)
[ "$image" = "ghcr.io/stefanprodan/podinfo:6.15.0" ] || fail "the image of scout changed to ${image}"
cpu_m=$(to_millicores "$(field resources.requests.cpu)")
mem_request=$(to_mebibytes "$(field resources.requests.memory)")
mem_limit=$(to_mebibytes "$(field resources.limits.memory)")
[ "$cpu_m" -ge 25 ] || fail "scout has a CPU request of ${cpu_m}m, expected at least 25m"
[ "$cpu_m" -le 250 ] || fail "scout still requests ${cpu_m}m CPU. It uses only a few millicores, so ask for at most 250m"
[ "$mem_request" -ge 24 ] || fail "scout has a memory request of ${mem_request}Mi, expected at least 24Mi"
[ "$mem_request" -le 256 ] || fail "scout still requests ${mem_request}Mi of memory, expected at most 256Mi"
[ "$mem_limit" -ge "$mem_request" ] || fail "scout has a memory limit of ${mem_limit}Mi, below its request of ${mem_request}Mi (or no limit)"
[ "$mem_limit" -le 512 ] || fail "scout has a memory limit of ${mem_limit}Mi, expected at most 512Mi"
echo "OK: scout requests ${cpu_m}m CPU and ${mem_request}Mi memory, limit ${mem_limit}Mi"

# --- 2. the HPA ---------------------------------------------------------------------
kubectl -n "$NS" get hpa scout >/dev/null 2>&1 || fail "the HPA scout does not exist in $NS"
target_kind=$(hpa '{.spec.scaleTargetRef.kind}/{.spec.scaleTargetRef.name}')
[ "$target_kind" = "Deployment/scout" ] || fail "the HPA scales ${target_kind}, expected Deployment/scout"
metric=$(hpa '{.spec.metrics[0].type}/{.spec.metrics[0].resource.name}/{.spec.metrics[0].resource.target.type}')
[ "$metric" = "Resource/cpu/Utilization" ] || fail "the HPA metric is ${metric}, expected Resource/cpu/Utilization"
target=$(hpa '{.spec.metrics[0].resource.target.averageUtilization}')
[ "${target:-0}" -ge 40 ] && [ "${target:-0}" -le 80 ] || fail "the CPU target is ${target:-unset} percent, expected 40 to 80"
min=$(hpa '{.spec.minReplicas}')
max=$(hpa '{.spec.maxReplicas}')
[ "${min:-1}" = "1" ] || fail "minReplicas is ${min}, expected 1"
[ "${max:-0}" -ge 3 ] && [ "${max:-0}" -le 6 ] || fail "maxReplicas is ${max:-unset}, expected 3 to 6"
echo "OK: the HPA scales Deployment/scout on CPU Utilization at ${target} percent, 1 to ${max} replicas"

# --- 3. the stabilization window ----------------------------------------------------
window=$(hpa '{.spec.behavior.scaleDown.stabilizationWindowSeconds}')
[ -n "$window" ] || fail "behavior.scaleDown.stabilizationWindowSeconds is not set"
[ "$window" -ge 30 ] && [ "$window" -le 90 ] || fail "stabilizationWindowSeconds is ${window}, expected 30 to 90"
echo "OK: scale-down stabilization window is ${window} seconds"

# --- 4. behaviour -------------------------------------------------------------------
kubectl -n "$NS" rollout status deploy/scout --timeout=180s >/dev/null 2>&1 || fail "the scout rollout did not finish"
resolved=""
for _ in $(seq 1 60); do
  utilisation=$(hpa '{.status.currentMetrics[0].resource.current.averageUtilization}')
  active=$(hpa '{.status.conditions[?(@.type=="ScalingActive")].status}')
  if [ -n "$utilisation" ] && [ "$active" = "True" ]; then resolved="yes"; break; fi
  sleep 5
done
[ -n "$resolved" ] || fail "the HPA does not read the CPU utilisation (ScalingActive='${active:-unknown}'). Check kubectl describe hpa scout"
echo "OK: the HPA reads ${utilisation}% CPU utilisation"

stop_load
kubectl -n "$NS" exec deploy/shuttle -- sh -c 'for i in 1 2 3 4; do timeout 240 curl -s -o /dev/null -X POST "http://scout/token?[1-5000000]" & done; wait' >/dev/null 2>&1 &
load_pid=$!

replicas=1
for _ in $(seq 1 48); do
  replicas=$(hpa '{.status.currentReplicas}')
  [ "${replicas:-1}" -ge 2 ] && break
  sleep 5
done
kill "$load_pid" 2>/dev/null; wait "$load_pid" 2>/dev/null
stop_load
[ "${replicas:-1}" -ge 2 ] || fail "the HPA reached only ${replicas:-1} replica under load from shuttle. Check the CPU request and the target"
echo "OK: scout scaled up to ${replicas} replicas under load"

echo "Load stopped. Waiting up to 5 minutes for the replicas to return to 1."
after=${replicas}
for _ in $(seq 1 60); do
  after=$(hpa '{.status.currentReplicas}')
  [ "${after:-99}" = "1" ] && [ "$(hpa '{.status.desiredReplicas}')" = "1" ] && break
  sleep 5
done
[ "${after:-99}" = "1" ] || fail "scout still has ${after} replicas 5 minutes after the load stopped, expected 1. Check behavior.scaleDown"
echo "OK: scout is back to 1 replica after the load stopped"

echo "PASS: scout is right-sized and the HPA scales it up under load and back down"
exit 0
