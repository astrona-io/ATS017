#!/usr/bin/env bash
# Shared live-state and admission checks. Only validator-owned claims are deleted.
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
read_quota() {
  kubectl -n "$NAMESPACE" get resourcequota pipeline-storage -o "jsonpath=$1"
}
check_quota() {
  local expected_count="$1" expected_storage="${2:-}" count storage
  local quota_names scopes limits
  quota_names=$(kubectl -n "$NAMESPACE" get resourcequota -o name) || fail 'cannot list quotas'
  # Name no namespace here: the start state must not reveal the Git answer.
  [ -n "$quota_names" ] || fail 'a namespace has no pipeline-storage ResourceQuota yet'
  [ "$quota_names" = resourcequota/pipeline-storage ] || fail 'keep only the pipeline-storage quota'
  scopes=$(read_quota '{.spec.scopes}{.spec.scopeSelector}') || fail 'cannot read quota scopes'
  [ -z "$scopes" ] || fail 'pipeline-storage must be unscoped'
  limits=$(kubectl -n "$NAMESPACE" get limitrange -o name) || fail 'cannot list LimitRanges'
  [ -z "$limits" ] || fail 'do not add a LimitRange'
  count=$(read_quota '{.spec.hard.persistentvolumeclaims}') || fail 'pipeline-storage quota is missing'
  [ "$count" = "$expected_count" ] || fail "persistentvolumeclaims must be ${expected_count} in ${NAMESPACE}"
  if [ -n "$expected_storage" ]; then
    storage=$(read_quota '{.spec.hard.requests\.storage}') || fail 'cannot read storage cap'
    [ "$storage" = "$expected_storage" ] || fail "requests.storage must be ${expected_storage} in ${NAMESPACE}"
  fi
  # Wait for the quota controller to observe the intended limits.
  for attempt in $(seq 1 30); do
    count=$(read_quota '{.status.hard.persistentvolumeclaims}') || fail 'cannot read quota status'
    storage=$(read_quota '{.status.hard.requests\.storage}') || fail 'cannot read quota status'
    if [ "$count" = "$expected_count" ] && { [ -z "$expected_storage" ] || [ "$storage" = "$expected_storage" ]; }; then
      return
    fi
    sleep 2
  done
  fail 'quota status has not caught up with spec.hard'
}
cleanup() {
  kubectl -n "$NAMESPACE" delete pvc quota-check-small-1 quota-check-small-2 \
    quota-check-over-count quota-check-over-storage quota-check-blocked \
    --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1
}
# Real creates deliberately have no consumer and no StorageClass. Pending
# claims still exercise quota admission without allocating test volumes.
create_claim() {
  local claim_name="$1" size="$2"
  kubectl -n "$NAMESPACE" create -f - 2>&1 <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${claim_name}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests:
      storage: ${size}
YAML
}
expect_allowed() {
  local result
  result=$(create_claim "$1" "$2") || fail "PVC $1 should be allowed: ${result}"
  kubectl -n "$NAMESPACE" get pvc "$1" >/dev/null || fail "allowed PVC $1 was not persisted"
}
expect_denied() {
  local result
  if result=$(create_claim "$1" "$2"); then
    fail "PVC $1 was allowed but should be denied"
  fi
  # Do not accept an authorization failure, an unrelated policy, or bad YAML.
  # The API server lists only the exceeded resources, sorted, after "requested:".
  [[ "$result" == *Forbidden* && "$result" == *"exceeded quota: pipeline-storage, requested: $3="* ]] || fail "expected quota rejection for $3: ${result}"
  local remaining
  remaining=$(kubectl -n "$NAMESPACE" get pvc "$1" --ignore-not-found -o name) || fail 'cannot verify rejected PVC absence'
  [ -z "$remaining" ] || fail "denied PVC $1 exists"
}
