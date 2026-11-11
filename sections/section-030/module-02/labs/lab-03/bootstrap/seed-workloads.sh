#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl apply -f "$DIR/bootstrap/manifests/lab-start.yaml"
kubectl -n starfleet rollout status deploy/shuttle --timeout=180s
kubectl -n starfleet get deploy scout-underprovisioned -o json > "$DIR/original-deployment.json"
kubectl -n starfleet get svc scout-underprovisioned -o json > "$DIR/original-service.json"
for attempt in $(seq 1 60); do
  reason="$(kubectl -n starfleet get pods -l app=scout-underprovisioned -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}')"
  if [ "$reason" = OOMKilled ]; then exit 0; fi
  sleep 3
done
echo 'The intended OOMKilled starting state did not appear' >&2
exit 1
