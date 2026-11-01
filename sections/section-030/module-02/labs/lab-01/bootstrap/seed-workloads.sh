#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-030-02-01.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# scout-underprovisioned is deliberately broken: its memory limit is below
# what the process holds, so the kernel kills the container (OOMKilled).
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl -n starfleet rollout status deploy/scout-overprovisioned --timeout=300s
kubectl -n starfleet rollout status deploy/shuttle --timeout=300s

echo "==> Waiting for the Metrics API"
for _ in $(seq 1 60); do
  available=$(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || true)
  [ "$available" = "True" ] && break
  sleep 3
done

echo "==> Waiting for scout-underprovisioned to be OOMKilled"
for _ in $(seq 1 60); do
  reason=$(kubectl -n starfleet get pods -l app=scout-underprovisioned -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || true)
  [ "$reason" = "OOMKilled" ] && break
  sleep 3
done
kubectl -n starfleet get pods

echo "==> Lab ats-017-lab-030-02-01 ready."
