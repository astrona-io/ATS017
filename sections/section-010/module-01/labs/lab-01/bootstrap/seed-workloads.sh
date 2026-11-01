#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-010-01-01.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# scout is deliberately broken: it allocates 100 MB with a 64Mi limit.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl -n starfleet rollout status deploy/shuttle --timeout=300s

echo "==> Waiting for the first OOMKilled restart of scout"
for _ in $(seq 1 60); do
  restarts=$(kubectl -n starfleet get pod -l app=scout -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo 0)
  [ "${restarts:-0}" -ge 1 ] && break
  sleep 3
done
kubectl -n starfleet get pods

echo "==> Lab ats-017-lab-010-01-01 ready."
