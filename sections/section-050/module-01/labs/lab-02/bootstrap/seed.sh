#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-050-01-02.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# The quota requires requests and a memory limit. batch-worker declares
# none, so the ReplicaSet cannot create a pod.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespace, quota and Deployment"
kubectl apply -f manifests/lab-start.yaml

echo "==> Waiting for the quota rejection"
for _ in $(seq 1 40); do
  failure=$(kubectl -n outpost get deploy batch-worker -o jsonpath='{.status.conditions[?(@.type=="ReplicaFailure")].status}' 2>/dev/null || true)
  [ "$failure" = "True" ] && break
  sleep 3
done
kubectl -n outpost get deploy batch-worker

echo "==> Lab ats-017-lab-050-01-02 ready."
