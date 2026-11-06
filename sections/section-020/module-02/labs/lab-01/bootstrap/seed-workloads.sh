#!/usr/bin/env bash
# Astrona supplies kubectl and KUBECONFIG. Every client has preloaded curl.
set -euo pipefail
cd "$(dirname "$0")/.."
kubectl apply -f manifests/lab-start.yaml
for workload in shuttle probe drifter; do
  kubectl -n starfleet rollout status "deploy/$workload" --timeout=300s
done
for workload in shuttle drifter; do
  kubectl -n outpost rollout status "deploy/$workload" --timeout=300s
done
kubectl -n relay rollout status deploy/shuttle --timeout=300s
kubectl apply -f manifests/broken-policy.yaml
