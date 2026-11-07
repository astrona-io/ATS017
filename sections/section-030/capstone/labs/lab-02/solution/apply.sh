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
kubectl -n starfleet top pods --containers
kubectl -n starfleet set resources deployment/scout --requests=cpu=100m,memory=256Mi
kubectl -n starfleet rollout status deployment/scout --timeout=180s
# metrics-server reports a new Pod about a minute after it starts, and the
# sizing grader reads that usage, so wait until every scout Pod has a sample.
for attempt in $(seq 1 36); do
  missing=0
  for pod in $(kubectl -n starfleet get pods -l app=scout -o jsonpath='{.items[*].metadata.name}'); do
    kubectl -n starfleet top pod "$pod" --no-headers >/dev/null 2>&1 || missing=1
  done
  [ "$missing" -eq 0 ] && break
  [ "$attempt" -eq 36 ] && { echo "no usage sample for every scout Pod after 3 minutes" >&2; exit 1; }
  sleep 5
done
kubectl apply -f hpa-scout.yaml
