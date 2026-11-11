#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl apply -f "$DIR/bootstrap/manifests/lab-start.yaml"
kubectl -n starfleet rollout status deploy/shuttle --timeout=180s
kubectl -n starfleet get deploy scout-overprovisioned -o json > "$DIR/original-deployment.json"
kubectl -n starfleet get svc scout-overprovisioned -o json > "$DIR/original-service.json"
kubectl -n starfleet rollout status deploy/scout-overprovisioned --timeout=180s
