#!/usr/bin/env bash
# Creates the starting state for ats-017-capstone-020.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# Creates no Gateway, HTTPRoute, NetworkPolicy or claim: those are the task.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Workloads"
kubectl apply -f manifests/lab-start.yaml

echo "==> Waiting for the workloads"
for deployment in bridge scout shuttle; do
  kubectl -n starfleet rollout status deploy/"$deployment" --timeout=300s
done
kubectl -n outpost rollout status deploy/shuttle --timeout=300s

echo "==> Lab ats-017-capstone-020 ready. Nothing the task asks for has been created."
