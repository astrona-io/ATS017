#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl apply -f "$DIR/manifests/start.yaml"
kubectl -n starfleet rollout status statefulset/probe --timeout=180s
for ordinal in 0 1; do
  token="claim-$ordinal-$(date +%s)-$RANDOM"
  kubectl -n starfleet exec "probe-$ordinal" -- sh -c 'printf "%s" "$1" > /data/record' sh "$token"
  printf '%s' "$token" > "$DIR/record-$ordinal"
done
kubectl -n starfleet get statefulset probe -o json > "$DIR/initial-statefulset.json"
kubectl -n starfleet get pvc data-probe-0 data-probe-1 -o json > "$DIR/initial-claims.json"
