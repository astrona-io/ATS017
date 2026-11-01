#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-020-03.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# The scout pod stays Pending on purpose: fixing that is the task.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Workloads"
kubectl apply -f manifests/lab-start.yaml

echo "==> Waiting for shuttle"
kubectl -n starfleet rollout status deploy/shuttle --timeout=300s

echo "==> Lab ats-017-lab-020-03 ready. scout is Pending; the task is to fix it."
