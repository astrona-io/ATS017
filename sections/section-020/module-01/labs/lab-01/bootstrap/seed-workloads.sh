#!/usr/bin/env bash
# Astrona supplies kubectl and KUBECONFIG; curl runs in the preloaded shuttle image.
set -euo pipefail
# Resolve the lab assets relative to this script, independent of the caller.
cd "$(dirname "$0")/.."
kubectl apply -f manifests/lab-start.yaml
for deployment in bridge scout probe; do
  kubectl -n outpost rollout status deploy/"$deployment" --timeout=300s
done
for deployment in bridge shuttle; do
  kubectl -n starfleet rollout status deploy/"$deployment" --timeout=300s
done
kubectl apply -f manifests/broken-routes.yaml
kubectl -n starfleet wait --for=condition=Programmed gateway/starfleet-gateway --timeout=300s
