#!/usr/bin/env bash
# Grading for ats-017-lab-050-01-02. Checks:
#   1. the ResourceQuota is unchanged and the Deployment template still has no resources
#   2. a LimitRange exists in outpost
#   3. three batch-worker pods are Ready with the default requests and limit
#   4. a bare pod without resources is accepted and gets the defaults
#   5. a pod with a 512Mi memory limit is rejected by the maximum
set -u

NS="outpost"
fail() { echo "FAIL: $*"; exit 1; }
cleanup() { kubectl -n "$NS" delete pod bare-check max-check --ignore-not-found --wait=false >/dev/null 2>&1; }
trap cleanup EXIT

# --- 1. quota and Deployment untouched ----------------------------------------------
kubectl -n "$NS" get resourcequota outpost-quota >/dev/null 2>&1 || fail "the ResourceQuota outpost-quota does not exist. Do not delete it"
[ "$(kubectl -n "$NS" get resourcequota outpost-quota -o jsonpath='{.spec.hard.requests\.cpu}')" = "400m" ] || fail "the quota requests.cpu was changed. The quota must stay as it is"
[ "$(kubectl -n "$NS" get resourcequota outpost-quota -o jsonpath='{.spec.hard.requests\.memory}')" = "512Mi" ] || fail "the quota requests.memory was changed. The quota must stay as it is"
[ "$(kubectl -n "$NS" get resourcequota outpost-quota -o jsonpath='{.spec.hard.limits\.memory}')" = "1Gi" ] || fail "the quota limits.memory was changed. The quota must stay as it is"
requests=$(kubectl -n "$NS" get deploy batch-worker -o jsonpath='{.spec.template.spec.containers[0].resources.requests}')
limits=$(kubectl -n "$NS" get deploy batch-worker -o jsonpath='{.spec.template.spec.containers[0].resources.limits}')
[ -z "$requests" ] && [ -z "$limits" ] || fail "the pod template of batch-worker declares resources. Leave it as it is and use a LimitRange"
[ "$(kubectl -n "$NS" get deploy batch-worker -o jsonpath='{.spec.replicas}')" = "3" ] || fail "batch-worker must keep 3 replicas"
echo "OK: the quota and the batch-worker template are unchanged"

# --- 2. a LimitRange exists ----------------------------------------------------------
count=$(kubectl -n "$NS" get limitrange -o name 2>/dev/null | wc -l | tr -d ' ')
[ "$count" -ge 1 ] || fail "there is no LimitRange in the namespace outpost"
echo "OK: the namespace has a LimitRange"

# --- 3. the pods run with the defaults -----------------------------------------------
ready=0
for _ in $(seq 1 60); do
  ready=$(kubectl -n "$NS" get pods -l app=batch-worker -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}|{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c '^|true$')
  [ "$ready" = "3" ] && break
  sleep 3
done
[ "$ready" = "3" ] || fail "only ${ready} of 3 batch-worker pods are Ready after 3 minutes. A ReplicaSet that failed earlier may need 'kubectl -n outpost rollout restart deployment/batch-worker'"
pod_values=$(kubectl -n "$NS" get pods -l app=batch-worker -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}|{.spec.containers[0].resources.requests.cpu}|{.spec.containers[0].resources.requests.memory}|{.spec.containers[0].resources.limits.memory}{"\n"}{end}' | grep '^|')
wrong=$(echo "$pod_values" | grep -vc '^|50m|64Mi|128Mi$')
[ "$wrong" = "0" ] || fail "the pods do not all have a 50m CPU request, a 64Mi memory request and a 128Mi memory limit: ${pod_values}"
echo "OK: 3 batch-worker pods are Ready with 50m, 64Mi and a 128Mi limit"

# --- 4. a bare pod gets the defaults -------------------------------------------------
cleanup
sleep 1
output=$(kubectl -n "$NS" run bare-check --image=mccutchen/go-httpbin:2.25.0 --restart=Never 2>&1) || fail "a pod without resources was rejected: ${output}"
bare=$(kubectl -n "$NS" get pod bare-check -o jsonpath='{.spec.containers[0].resources.requests.cpu}|{.spec.containers[0].resources.requests.memory}|{.spec.containers[0].resources.limits.memory}')
[ "$bare" = "50m|64Mi|128Mi" ] || fail "a pod without resources got '${bare}', expected 50m|64Mi|128Mi"
echo "OK: a pod without resources is accepted and gets the defaults"

# --- 5. the maximum rejects a large limit --------------------------------------------
output=$(kubectl -n "$NS" apply -f - 2>&1 <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: max-check
spec:
  containers:
    - name: probe
      image: mccutchen/go-httpbin:2.25.0
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          memory: 512Mi
YAML
)
echo "$output" | grep -q "maximum memory usage per Container" || fail "a pod with a 512Mi memory limit was not rejected by a LimitRange maximum: ${output}"
echo "OK: a pod with a 512Mi memory limit is rejected"

echo "PASS: the LimitRange gives default resources and enforces the maximum"
exit 0
