#!/usr/bin/env bash
# Creates the starting state for ats-017-capstone-030.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl -n starfleet rollout status deploy/scout --timeout=300s
kubectl -n starfleet rollout status deploy/shuttle --timeout=300s

echo "==> Waiting for the Metrics API"
for _ in $(seq 1 60); do
  available=$(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || true)
  [ "$available" = "True" ] && break
  sleep 3
done

kubectl -n starfleet get pods

echo "==> Lab ats-017-capstone-030 ready."
