#!/usr/bin/env bash
# Sourced by one wrapper for each bounded namespace.
source "$(dirname "${BASH_SOURCE[0]}")/storage-helpers.sh"
check_quota "$CLAIM_CAP" "$STORAGE_CAP"
# Fail rather than remove any PVC the learner created or retained.
claims=$(kubectl -n "$NAMESPACE" get pvc -o name) || fail 'cannot list PVCs'
[ "$claims" = persistentvolumeclaim/pipeline-cache ] || fail 'keep only the original pipeline-cache claim before submitting'
size=$(kubectl -n "$NAMESPACE" get pvc pipeline-cache -o jsonpath='{.spec.resources.requests.storage}') || fail 'cannot read pipeline-cache'
[ "$size" = 1Gi ] || fail 'keep pipeline-cache at 1Gi'
replicas=$(kubectl -n "$NAMESPACE" get deployment cache-reader -o jsonpath='{.spec.replicas}') || fail 'keep cache-reader'
[ "$replicas" = 1 ] || fail 'keep cache-reader at one replica'
mounted=$(kubectl -n "$NAMESPACE" get deployment cache-reader -o jsonpath='{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}') || fail 'cannot read cache-reader volumes'
[ "$mounted" = pipeline-cache ] || fail 'keep pipeline-cache mounted in cache-reader'
kubectl -n "$NAMESPACE" rollout status deployment/cache-reader --timeout=60s || fail 'cache-reader must remain available'
# Deleted test claims may leave quota usage stale briefly between submissions.
for attempt in $(seq 1 30); do
  used_count=$(read_quota '{.status.used.persistentvolumeclaims}') || fail 'cannot read quota usage'
  used_storage=$(read_quota '{.status.used.requests\.storage}') || fail 'cannot read quota usage'
  [ "$used_count" = 1 ] && [ "$used_storage" = 1Gi ] && break
  sleep 2
done
[ "$used_count" = 1 ] && [ "$used_storage" = 1Gi ] || fail 'wait for quota usage to show the original 1Gi claim only'
trap cleanup EXIT
# With only 1Gi in use and room in the count, this exceeds only storage.
expect_denied quota-check-over-storage "$STORAGE_CAP" requests.storage
# Fill the count with tiny claims, staying well below the storage cap.
expect_allowed quota-check-small-1 1Mi
if [ "$CLAIM_CAP" = 3 ]; then
  expect_allowed quota-check-small-2 1Mi
fi
expect_denied quota-check-over-count 1Mi persistentvolumeclaims
cleanup || fail 'could not remove validator-owned PVCs'
trap - EXIT
echo "PASS: ${CHECK_NAME} — small PVCs are allowed and count and storage excesses are denied"
