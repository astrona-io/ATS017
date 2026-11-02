#!/usr/bin/env bash
# Grading for ats-017-lab-050-03-02. The grader creates its own namespaces, so
# a hand-made quota in a fixed namespace does not pass. Checks:
#   1. a namespace with the label tenant=true gets a ResourceQuota tenant-quota
#      (requests.cpu 200m, requests.memory 256Mi, limits.memory 512Mi, pods 10)
#   2. the same namespace gets a LimitRange tenant-defaults (25m, 32Mi, limit 64Mi, max 128Mi)
#   3. a namespace without the label gets neither
#   4. a deleted quota is created again (synchronize)
#   5. a pod without resources gets the defaults
#   6. a pod with a 256Mi memory limit is rejected
set -u

TENANT="grade-tenant"
PLAIN="grade-plain"
fail() { echo "FAIL: $*"; exit 1; }
cleanup() { kubectl delete namespace "$TENANT" "$PLAIN" --ignore-not-found --wait=false >/dev/null 2>&1; }
trap cleanup EXIT

cleanup
for _ in $(seq 1 60); do
  kubectl get namespace "$TENANT" >/dev/null 2>&1 || kubectl get namespace "$PLAIN" >/dev/null 2>&1 || break
  sleep 3
done

# Retry creating the namespaces while the Kyverno webhook starts to use the policy.
kubectl create namespace "$PLAIN" >/dev/null 2>&1 || fail "cannot create the namespace $PLAIN"

wait_for() { # description command...
  local what=$1; shift
  for _ in $(seq 1 40); do
    if "$@" >/dev/null 2>&1; then return 0; fi
    sleep 3
  done
  fail "$what"
}

# --- 1 + 2. generated objects ----------------------------------------------------------
# A policy applied a moment ago may not match yet, so create the tenant namespace
# again if nothing appears in a minute.
kubectl create namespace "$TENANT" >/dev/null 2>&1 || fail "cannot create the namespace $TENANT"
kubectl label namespace "$TENANT" tenant=true --overwrite >/dev/null
quota_found=0
for attempt in 1 2 3; do
  for _ in $(seq 1 20); do
    if kubectl -n "$TENANT" get resourcequota tenant-quota >/dev/null 2>&1; then quota_found=1; break; fi
    sleep 3
  done
  [ "$quota_found" = "1" ] && break
  kubectl label namespace "$TENANT" tenant- >/dev/null; sleep 2
  kubectl label namespace "$TENANT" tenant=true >/dev/null
done
[ "$quota_found" = "1" ] || fail "no ResourceQuota tenant-quota appeared in a namespace labeled tenant=true. Use a ClusterPolicy generate rule that matches Namespaces with the label tenant: \"true\""

hard() { kubectl -n "$TENANT" get resourcequota tenant-quota -o jsonpath="{.spec.hard.$1}" 2>/dev/null; }
[ "$(hard 'requests\.cpu')" = "200m" ] || fail "tenant-quota requests.cpu is '$(hard 'requests\.cpu')', expected 200m"
[ "$(hard 'requests\.memory')" = "256Mi" ] || fail "tenant-quota requests.memory is '$(hard 'requests\.memory')', expected 256Mi"
[ "$(hard 'limits\.memory')" = "512Mi" ] || fail "tenant-quota limits.memory is '$(hard 'limits\.memory')', expected 512Mi"
[ "$(hard 'pods')" = "10" ] || fail "tenant-quota pods is '$(hard 'pods')', expected 10"
echo "OK: the labeled namespace has the generated ResourceQuota tenant-quota"

wait_for "no LimitRange tenant-defaults appeared in the labeled namespace" kubectl -n "$TENANT" get limitrange tenant-defaults
lr=$(kubectl -n "$TENANT" get limitrange tenant-defaults -o jsonpath='{.spec.limits[0].type}|{.spec.limits[0].defaultRequest.cpu}|{.spec.limits[0].defaultRequest.memory}|{.spec.limits[0].default.memory}|{.spec.limits[0].max.memory}')
[ "$lr" = "Container|25m|32Mi|64Mi|128Mi" ] || fail "the LimitRange is '${lr}', expected Container|25m|32Mi|64Mi|128Mi (type|defaultRequest cpu|defaultRequest memory|default memory|max memory)"
echo "OK: the labeled namespace has the generated LimitRange tenant-defaults"

# --- 3. the unlabeled namespace gets nothing -----------------------------------------------
sleep 5
count=$(kubectl -n "$PLAIN" get resourcequota,limitrange -o name 2>/dev/null | wc -l | tr -d ' ')
[ "$count" = "0" ] || fail "the namespace without the label got ${count} generated object(s). The rule must match only namespaces with tenant: \"true\""
echo "OK: a namespace without the label gets nothing"

# --- 4. synchronize --------------------------------------------------------------------------
kubectl -n "$TENANT" delete resourcequota tenant-quota >/dev/null 2>&1
wait_for "the deleted ResourceQuota was not created again. Set synchronize: true on the generate rule" kubectl -n "$TENANT" get resourcequota tenant-quota
echo "OK: a deleted ResourceQuota is created again"

# --- 5. defaults on a pod --------------------------------------------------------------------
output=$(kubectl -n "$TENANT" run bare-check --image=mccutchen/go-httpbin:2.25.0 --restart=Never 2>&1) || fail "a pod without resources was rejected in the tenant namespace: ${output}"
bare=$(kubectl -n "$TENANT" get pod bare-check -o jsonpath='{.spec.containers[0].resources.requests.cpu}|{.spec.containers[0].resources.requests.memory}|{.spec.containers[0].resources.limits.memory}')
[ "$bare" = "25m|32Mi|64Mi" ] || fail "a pod without resources got '${bare}', expected 25m|32Mi|64Mi"
echo "OK: a pod without resources gets the defaults"

# --- 6. the maximum rejects a large limit ------------------------------------------------------
output=$(kubectl -n "$TENANT" apply -f - 2>&1 <<'YAML'
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
          cpu: 10m
          memory: 16Mi
        limits:
          memory: 256Mi
YAML
)
echo "$output" | grep -q "maximum memory usage per Container" || fail "a pod with a 256Mi memory limit was not rejected by the LimitRange maximum: ${output}"
echo "OK: a pod with a 256Mi memory limit is rejected"

echo "PASS: the generate policy gives every tenant namespace its quota and defaults"
exit 0
