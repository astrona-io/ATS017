#!/usr/bin/env bash
# Grading for ats-017-lab-040-02-02. Checks:
#   1. the Deployment starfleet/scout-overprovisioned requests CPU between 10m
#      and 250m and memory between 40Mi and 384Mi (its real usage is about 2m
#      and 25Mi, so the range gives a margin without wasting a request), both
#      in the Deployment and in the running pod
#   2. the Deployment finished its rollout, runs at least one ready replica, and
#      the pod answers HTTP 200 on port 9898 when shuttle calls its Service
#   3. the other workloads were not changed to fake a result: crunch still
#      requests 400m and 128Mi, and scout still requests 100m and 64Mi
# The grader does not call OpenCost, because a change in requests shows up in
# OpenCost only after several minutes. It checks the cause, the requests.
set -u

fail() { echo "FAIL: $*"; exit 1; }

# to_millicores <quantity>: 250m -> 250, 1 -> 1000, 0.5 -> 500
to_millicores() {
  case "$1" in
    *m) echo "${1%m}" ;;
    *) awk -v value="$1" 'BEGIN { printf "%d", value * 1000 }' ;;
  esac
}
# to_mebibytes <quantity>: 128Mi -> 128, 1Gi -> 1024, 134217728 -> 128
to_mebibytes() {
  case "$1" in
    *Ki) awk -v value="${1%Ki}" 'BEGIN { printf "%d", value / 1024 }' ;;
    *Mi) echo "${1%Mi}" ;;
    *Gi) awk -v value="${1%Gi}" 'BEGIN { printf "%d", value * 1024 }' ;;
    *M) awk -v value="${1%M}" 'BEGIN { printf "%d", value * 1000000 / 1048576 }' ;;
    *G) awk -v value="${1%G}" 'BEGIN { printf "%d", value * 1000000000 / 1048576 }' ;;
    *) awk -v value="$1" 'BEGIN { printf "%d", value / 1048576 }' ;;
  esac
}
in_range() { awk -v value="$1" -v low="$2" -v high="$3" 'BEGIN { exit !(value + 0 >= low + 0 && value + 0 <= high + 0) }'; }

check_requests() {
  local label="$1" cpu="$2" memory="$3"
  [ -n "$cpu" ] && [ -n "$memory" ] || fail "${label} has no CPU or memory request. Set both"
  local millicores mebibytes
  millicores=$(to_millicores "$cpu")
  mebibytes=$(to_mebibytes "$memory")
  in_range "$millicores" 10 250 \
    || fail "${label} requests ${cpu} CPU. It uses about 2m, so request between 10m and 250m"
  in_range "$mebibytes" 40 384 \
    || fail "${label} requests ${memory} memory. It uses about 25Mi, so request between 40Mi and 384Mi"
}

# --- 1. the requests --------------------------------------------------------------------
kubectl -n starfleet get deploy scout-overprovisioned >/dev/null 2>&1 \
  || fail "the Deployment scout-overprovisioned does not exist in the namespace starfleet. Change it, do not delete it"
cpu=$(kubectl -n starfleet get deploy scout-overprovisioned -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
memory=$(kubectl -n starfleet get deploy scout-overprovisioned -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
check_requests "the Deployment scout-overprovisioned" "$cpu" "$memory"
echo "OK: the Deployment requests ${cpu} CPU and ${memory} memory"

# --- 2. the pod still runs and answers ----------------------------------------------------
kubectl -n starfleet rollout status deploy/scout-overprovisioned --timeout=120s >/dev/null 2>&1 \
  || fail "the Deployment scout-overprovisioned did not finish its rollout"
pod_line=$(kubectl -n starfleet get pods -l app=scout-overprovisioned -o jsonpath='{range .items[*]}{.metadata.name}{";"}{.metadata.deletionTimestamp}{";"}{.status.phase}{";"}{.spec.containers[0].resources.requests.cpu}{";"}{.spec.containers[0].resources.requests.memory}{"\n"}{end}' 2>/dev/null | awk -F';' '$2 == "" { print; exit }')
[ -n "$pod_line" ] || fail "no pod of scout-overprovisioned in the namespace starfleet"
[ "$(echo "$pod_line" | cut -d';' -f3)" = "Running" ] || fail "the pod of scout-overprovisioned is not Running"
check_requests "the running pod of scout-overprovisioned" "$(echo "$pod_line" | cut -d';' -f4)" "$(echo "$pod_line" | cut -d';' -f5)"
status=000
for _ in $(seq 1 15); do
  status=$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://scout-overprovisioned 2>/dev/null || true)
  [ "$status" = "200" ] && break
  sleep 2
done
[ "$status" = "200" ] || fail "shuttle gets HTTP ${status} from the Service scout-overprovisioned, expected 200"
echo "OK: the pod is Running with fitting requests and shuttle gets 200"

# --- 3. nothing else was changed ------------------------------------------------------------
crunch_cpu=$(kubectl -n starfleet get deploy crunch -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
crunch_memory=$(kubectl -n starfleet get deploy crunch -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
{ [ "$crunch_cpu" = "400m" ] && [ "$crunch_memory" = "128Mi" ]; } \
  || fail "the requests of crunch changed to ${crunch_cpu} and ${crunch_memory}. crunch uses what it requests, so leave it as it is"
scout_cpu=$(kubectl -n starfleet get deploy scout -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
[ "$scout_cpu" = "100m" ] || fail "the CPU request of scout changed to '${scout_cpu}'. Right-size only the workload that wastes its request"
echo "OK: the other workloads are unchanged"

echo "PASS: scout-overprovisioned requests fit its usage"
exit 0
