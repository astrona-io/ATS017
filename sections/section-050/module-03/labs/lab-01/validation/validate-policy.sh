#!/usr/bin/env bash
# Grading for ats-017-lab-050-03-01. Checks behaviour:
#   1. a pod in outpost without resources is denied by Kyverno
#   2. a pod in outpost with requests but no memory limit is denied by Kyverno
#   3. a pod in outpost with requests and a memory limit is accepted
#   4. a pod without resources in starfleet is accepted (the policy is for outpost)
#   5. the probe Deployment in outpost still runs
set -u

fail() { echo "FAIL: $*"; exit 1; }
cleanup() {
  kubectl -n outpost delete pod check-bare check-nolimit check-ok --ignore-not-found --wait=false >/dev/null 2>&1
  kubectl -n starfleet delete pod check-other --ignore-not-found --wait=false >/dev/null 2>&1
}
trap cleanup EXIT

pod_yaml() { # name namespace mode(bare|nolimit|full)
  echo "apiVersion: v1
kind: Pod
metadata:
  name: $1
  namespace: $2
spec:
  containers:
    - name: probe
      image: mccutchen/go-httpbin:2.25.0"
  case "$3" in
    nolimit) echo "      resources:
        requests:
          cpu: 10m
          memory: 16Mi" ;;
    full) echo "      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          memory: 32Mi" ;;
  esac
}

# expect_denied: create a pod, retry while the Kyverno webhook starts to use the policy
expect_denied() { # name namespace mode
  local output
  for _ in $(seq 1 40); do
    if output=$(pod_yaml "$1" "$2" "$3" | kubectl apply -f - 2>&1); then
      kubectl -n "$2" delete pod "$1" --ignore-not-found --wait=true >/dev/null 2>&1
      sleep 3
    else
      if echo "$output" | grep -qi "kyverno"; then return 0; fi
      echo "$output"
      return 1
    fi
  done
  echo "the pod $1 was accepted every time"
  return 1
}

# --- 1. a pod without resources is denied -----------------------------------------------
result=$(expect_denied check-bare outpost bare) || fail "a pod without resources in outpost was not denied by Kyverno: ${result}. Use a ClusterPolicy with failureAction Enforce"
echo "OK: a pod without resources is denied by Kyverno"

# --- 2. a pod without a memory limit is denied ------------------------------------------
result=$(expect_denied check-nolimit outpost nolimit) || fail "a pod with requests but no memory limit was not denied by Kyverno: ${result}. The rule must require limits.memory too"
echo "OK: a pod without a memory limit is denied by Kyverno"

# --- 3. a pod with resources is accepted ------------------------------------------------
output=$(pod_yaml check-ok outpost full | kubectl apply -f - 2>&1) || fail "a pod with requests and a memory limit was rejected: ${output}"
echo "OK: a pod with requests and a memory limit is accepted"

# --- 4. other namespaces are not affected -----------------------------------------------
output=$(pod_yaml check-other starfleet bare | kubectl apply -f - 2>&1) || fail "a pod without resources in starfleet was rejected: ${output}. The policy is for outpost only"
echo "OK: a pod without resources in starfleet is accepted"

# --- 5. probe still runs ----------------------------------------------------------------
ready=0
for _ in $(seq 1 30); do
  ready=$(kubectl -n outpost get pods -l app=probe -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}|{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c '^|true$')
  [ "$ready" -ge 1 ] && break
  sleep 3
done
[ "$ready" -ge 1 ] || fail "the probe pod in outpost is not Ready. Do not delete it"
echo "OK: probe still runs"

echo "PASS: Kyverno denies pods in outpost that miss requests or a memory limit"
exit 0
