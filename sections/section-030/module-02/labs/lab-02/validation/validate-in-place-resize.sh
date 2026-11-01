#!/usr/bin/env bash
# Grading for ats-017-lab-030-02-02. Checks:
#   1. the scout pod is the pod that existed at the start (same UID)
#   2. its container did not restart (restartCount 0) and is Ready
#   3. the container runs with a CPU request of 500m and a CPU limit of 1
#      (read from status.containerStatuses[].resources)
#   4. the memory request and limit are unchanged, and no resize is pending
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
pod_field() { kubectl -n "$NS" get pod "$pod" -o jsonpath="$1" 2>/dev/null; }

# --- 1. the same pod ----------------------------------------------------------------
expected_uid=$(kubectl -n kube-system get configmap lab-030-02-02-state -o jsonpath='{.data.podUID}' 2>/dev/null)
[ -n "$expected_uid" ] || fail "the lab state is missing. Restart the lab"
pods=$(kubectl -n "$NS" get pods -l app=scout -o jsonpath='{.items[*].metadata.name}')
[ -n "$pods" ] || fail "there is no scout pod"
pod=""
for candidate in $pods; do
  uid=$(kubectl -n "$NS" get pod "$candidate" -o jsonpath='{.metadata.uid}')
  [ "$uid" = "$expected_uid" ] && pod="$candidate"
done
[ -n "$pod" ] || fail "the original scout pod is gone. A new pod runs (${pods}). Resize the running pod, do not change the Deployment"
echo "OK: the original scout pod ${pod} is still running (UID unchanged)"

# --- 2. no restart ------------------------------------------------------------------
restarts=$(pod_field '{.status.containerStatuses[0].restartCount}')
[ "$restarts" = "0" ] || fail "the container restarted (restartCount ${restarts})"
echo "OK: the container was not restarted"

# --- 3. the resources the container runs with ---------------------------------------
resized=""
for _ in $(seq 1 30); do
  request_m=$(to_millicores "$(pod_field '{.status.containerStatuses[0].resources.requests.cpu}')")
  limit_m=$(to_millicores "$(pod_field '{.status.containerStatuses[0].resources.limits.cpu}')")
  pending=$(pod_field '{.status.conditions[?(@.type=="PodResizePending")].status}')
  progress=$(pod_field '{.status.conditions[?(@.type=="PodResizeInProgress")].status}')
  if [ "$request_m" -eq 500 ] && [ "$limit_m" -eq 1000 ] && [ "$pending" != "True" ] && [ "$progress" != "True" ]; then resized="yes"; break; fi
  sleep 3
done
[ -n "$resized" ] || fail "the container runs with a CPU request of ${request_m}m and a CPU limit of ${limit_m}m (resize pending: '${pending:-no}', in progress: '${progress:-no}'). Expected 500m and 1"
echo "OK: the container runs with a CPU request of 500m and a CPU limit of 1"

# --- 4. memory unchanged, still Ready -----------------------------------------------
memory=$(pod_field '{.status.containerStatuses[0].resources.requests.memory}/{.status.containerStatuses[0].resources.limits.memory}')
[ "$memory" = "64Mi/128Mi" ] || fail "the memory request and limit are ${memory}, expected 64Mi/128Mi"
ready=$(pod_field '{.status.containerStatuses[0].ready}')
[ "$ready" = "true" ] || fail "the scout container is not Ready"
echo "OK: memory is unchanged and the container is Ready"

echo "PASS: the running scout pod got more CPU in place, without a restart"
exit 0
