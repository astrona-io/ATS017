#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-050-01-01.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# The quota allows 500m of CPU requests. probe asks for 4 x 200m, so only
# two pods fit and the ReplicaSet reports a quota rejection.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace, quota and Deployment"
kubectl apply -f manifests/lab-start.yaml

echo "==> Waiting for the quota rejection"
for _ in $(seq 1 40); do
  failure=$(kubectl -n outpost get deploy probe -o jsonpath='{.status.conditions[?(@.type=="ReplicaFailure")].status}' 2>/dev/null || true)
  ready=$(kubectl -n outpost get deploy probe -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
  [ "$failure" = "True" ] && [ "${ready:-0}" = "2" ] && break
  sleep 3
done
kubectl -n outpost get deploy probe

echo "==> Lab ats-017-lab-050-01-01 ready."
