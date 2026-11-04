#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
kubectl apply -f vpa-probe.yaml
kubectl apply -f vpa-scout.yaml
for name in probe scout; do
  kubectl -n starfleet wait --for=condition=RecommendationProvided "vpa/$name" --timeout=600s
done
kubectl -n starfleet delete pod probe-0
kubectl -n starfleet rollout status statefulset/probe --timeout=180s
kubectl -n starfleet rollout restart deployment/scout
kubectl -n starfleet rollout status deployment/scout --timeout=180s
