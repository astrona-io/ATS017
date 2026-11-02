#!/usr/bin/env bash
# Grading for ats-017-lab-050-02-02. Checks behaviour in outpost:
#   1. the beacon pods and the PriorityClass are untouched
#   2. a third pod of the class platform-high is rejected by a quota
#   3. a pod without resources is rejected by a quota
#   4. an ordinary pod with requests and no class is accepted
#   5. a platform-high pod in starfleet is accepted (the limit is per namespace)
set -u

fail() { echo "FAIL: $*"; exit 1; }
cleanup() {
  kubectl -n outpost delete pod check-high check-bare check-plain --ignore-not-found --wait=false >/dev/null 2>&1
  kubectl -n starfleet delete pod check-high-other --ignore-not-found --wait=false >/dev/null 2>&1
}
trap cleanup EXIT

pod_yaml() { # name namespace class resources(yes|no)
  echo "apiVersion: v1
kind: Pod
metadata:
  name: $1
  namespace: $2
spec:"
  [ -n "$3" ] && echo "  priorityClassName: $3"
  echo "  containers:
    - name: probe
      image: mccutchen/go-httpbin:2.25.0"
  if [ "$4" = "yes" ]; then
    echo "      resources:
        requests:
          cpu: 10m
          memory: 16Mi"
  fi
}

# --- 1. untouched ------------------------------------------------------------------------
[ "$(kubectl get priorityclass platform-high -o jsonpath='{.value}' 2>/dev/null)" = "100000" ] || fail "the PriorityClass platform-high must exist with value 100000. Do not change it"
[ "$(kubectl -n outpost get deploy beacon -o jsonpath='{.spec.replicas}' 2>/dev/null)" = "2" ] || fail "beacon must keep 2 replicas"
ready=0
for _ in $(seq 1 40); do
  ready=$(kubectl -n outpost get pods -l app=beacon -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}|{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c '^|true$')
  [ "$ready" = "2" ] && break
  sleep 3
done
[ "$ready" = "2" ] || fail "the 2 beacon pods must stay Ready. Do not delete them"
echo "OK: platform-high and the 2 beacon pods are untouched"

# expect_rejected: try to create a pod, retry while the quota status catches up
expect_rejected() { # name namespace class resources pattern
  local output
  for _ in $(seq 1 30); do
    if output=$(pod_yaml "$1" "$2" "$3" "$4" | kubectl apply -f - 2>&1); then
      kubectl -n "$2" delete pod "$1" --ignore-not-found --wait=true >/dev/null 2>&1
      sleep 2
    else
      echo "$output" | grep -q "$5" && return 0
      echo "$output"
      return 1
    fi
  done
  echo "the pod $1 was accepted every time"
  return 1
}

# --- 2. a third platform-high pod is rejected ---------------------------------------------
result=$(expect_rejected check-high outpost platform-high yes "exceeded quota") || fail "a third platform-high pod in outpost was not rejected by a quota: ${result}"
echo "OK: a third platform-high pod is rejected (exceeded quota)"

# --- 3. a pod without resources is rejected -----------------------------------------------
result=$(expect_rejected check-bare outpost "" no "exceeded quota") || fail "a pod without resources in outpost was not rejected by a quota: ${result}"
echo "OK: a pod without resources is rejected (exceeded quota)"

# --- 4. an ordinary pod is accepted -------------------------------------------------------
output=$(pod_yaml check-plain outpost "" yes | kubectl apply -f - 2>&1) || fail "an ordinary pod with requests and no PriorityClass was rejected: ${output}. The limit must count only platform-high pods"
echo "OK: an ordinary pod with requests is accepted"

# --- 5. the limit is per namespace --------------------------------------------------------
output=$(pod_yaml check-high-other starfleet platform-high yes | kubectl apply -f - 2>&1) || fail "a platform-high pod in starfleet was rejected: ${output}. Create the quota only in outpost"
echo "OK: a platform-high pod in starfleet is accepted"

echo "PASS: the scoped quotas limit platform-high pods and pods without resources in outpost"
exit 0
