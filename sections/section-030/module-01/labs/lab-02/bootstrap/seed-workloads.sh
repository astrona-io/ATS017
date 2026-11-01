#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-030-01-02.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# The HPA for scout works but has no behavior section.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Workloads and HPA"
kubectl apply -f manifests/lab-start.yaml
kubectl -n starfleet rollout status deploy/scout --timeout=300s
kubectl -n starfleet rollout status deploy/shuttle --timeout=300s

echo "==> Waiting for the Metrics API"
for _ in $(seq 1 60); do
  available=$(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || true)
  [ "$available" = "True" ] && break
  sleep 3
done

echo "==> Waiting for the HPA to read its CPU target"
for _ in $(seq 1 40); do
  active=$(kubectl -n starfleet get hpa scout -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}' 2>/dev/null || true)
  [ "$active" = "True" ] && break
  sleep 3
done
kubectl -n starfleet get hpa

echo "==> Lab ats-017-lab-030-01-02 ready."
