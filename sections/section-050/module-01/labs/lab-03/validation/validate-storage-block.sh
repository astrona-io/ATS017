#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./storage-helpers.sh
NAMESPACE=pipeline-shuttle
check_quota 0
replicas=$(kubectl -n "$NAMESPACE" get deployment cache-reader -o jsonpath='{.spec.replicas}') || fail 'keep the cache-reader Deployment'
[ "$replicas" = 0 ] || fail 'scale cache-reader to zero replicas'
claims=$(kubectl -n "$NAMESPACE" get pvc -o name) || fail 'cannot list PVCs'
[ -z "$claims" ] || fail 'remove every existing PVC from the blocked namespace'
pods=$(kubectl -n "$NAMESPACE" get pods -o name) || fail 'cannot list consumer pods'
[ -z "$pods" ] || fail 'wait for all consumer pods to be deleted'
trap cleanup EXIT
expect_denied quota-check-blocked 1Mi persistentvolumeclaims
echo 'PASS: storage-block — no claims or consumers remain and quota denies a real PVC create'
