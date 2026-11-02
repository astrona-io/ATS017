#!/usr/bin/env bash
# Grading for ats-017-lab-050-01-01. Checks:
#   1. the ResourceQuota outpost-quota still has its original limits
#   2. probe still has 4 replicas and a CPU request between 50m and 120m
#   3. four probe pods are Ready (pods being deleted are ignored)
#   4. the quota still enforces: a pod that asks for 1 CPU is rejected
set -u

NS="outpost"
fail() { echo "FAIL: $*"; exit 1; }

to_millicores() {
  case "$1" in
    *m) echo "${1%m}" ;;
    "") echo 0 ;;
    *[!0-9]*) echo 0 ;;
    *) echo $(( $1 * 1000 )) ;;
  esac
}

# --- 1. the quota is unchanged ------------------------------------------------------
kubectl -n "$NS" get resourcequota outpost-quota >/dev/null 2>&1 || fail "the ResourceQuota outpost-quota does not exist. Fix the Deployment, do not delete the quota"
hard_cpu=$(kubectl -n "$NS" get resourcequota outpost-quota -o jsonpath='{.spec.hard.requests\.cpu}')
hard_memory=$(kubectl -n "$NS" get resourcequota outpost-quota -o jsonpath='{.spec.hard.requests\.memory}')
hard_limits=$(kubectl -n "$NS" get resourcequota outpost-quota -o jsonpath='{.spec.hard.limits\.memory}')
hard_pods=$(kubectl -n "$NS" get resourcequota outpost-quota -o jsonpath='{.spec.hard.pods}')
[ "$hard_cpu" = "500m" ] || fail "the quota requests.cpu is '${hard_cpu}', expected 500m. Do not change the quota"
[ "$hard_memory" = "512Mi" ] || fail "the quota requests.memory is '${hard_memory}', expected 512Mi. Do not change the quota"
[ "$hard_limits" = "1Gi" ] || fail "the quota limits.memory is '${hard_limits}', expected 1Gi. Do not change the quota"
[ "$hard_pods" = "10" ] || fail "the quota pods is '${hard_pods}', expected 10. Do not change the quota"
echo "OK: the ResourceQuota outpost-quota is unchanged"

# --- 2. the Deployment ---------------------------------------------------------------
replicas=$(kubectl -n "$NS" get deploy probe -o jsonpath='{.spec.replicas}' 2>/dev/null)
[ "$replicas" = "4" ] || fail "probe has ${replicas:-no} replicas, expected 4. Do not scale it down"
request=$(kubectl -n "$NS" get deploy probe -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
[ -n "$request" ] || fail "probe has no CPU request. The quota requires one"
request_m=$(to_millicores "$request")
[ "$request_m" -ge 50 ] || fail "the CPU request is ${request}, expected at least 50m"
[ "$request_m" -le 120 ] || fail "the CPU request is ${request}, expected at most 120m so that four replicas fit"
echo "OK: probe keeps 4 replicas with a CPU request of ${request}"

# --- 3. four pods are Ready ----------------------------------------------------------
ready=0
for _ in $(seq 1 60); do
  ready=$(kubectl -n "$NS" get pods -l app=probe -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}|{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c '^|true$')
  [ "$ready" = "4" ] && break
  sleep 3
done
[ "$ready" = "4" ] || fail "only ${ready} of 4 probe pods are Ready after 3 minutes. Check the events of the ReplicaSet"
echo "OK: 4 probe pods are Ready"

# --- 4. the quota still enforces -----------------------------------------------------
output=$(kubectl -n "$NS" apply -f - 2>&1 <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: quota-check
spec:
  containers:
    - name: probe
      image: mccutchen/go-httpbin:2.25.0
      resources:
        requests:
          cpu: "1"
          memory: 32Mi
        limits:
          memory: 64Mi
YAML
)
if echo "$output" | grep -q "exceeded quota"; then
  echo "OK: the quota still rejects a pod that asks for 1 CPU"
else
  kubectl -n "$NS" delete pod quota-check --ignore-not-found >/dev/null 2>&1
  fail "a pod that asks for 1 CPU was not rejected by the quota"
fi

echo "PASS: probe runs 4 replicas inside the unchanged quota"
exit 0
