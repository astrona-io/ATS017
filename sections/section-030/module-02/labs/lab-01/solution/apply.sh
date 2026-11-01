#!/usr/bin/env bash
# Reference solution for ats-017-lab-030-02-01. Applied only by `astrona test`.
set -euo pipefail

# scout-overprovisioned uses about 1m CPU and 15Mi of memory.
kubectl -n starfleet set resources deployment/scout-overprovisioned \
  --requests=cpu=20m,memory=32Mi --limits=memory=64Mi
# scout-underprovisioned holds about 110Mi of memory.
kubectl -n starfleet set resources deployment/scout-underprovisioned \
  --requests=cpu=20m,memory=160Mi --limits=memory=160Mi

kubectl -n starfleet rollout status deployment/scout-overprovisioned --timeout=180s
kubectl -n starfleet rollout status deployment/scout-underprovisioned --timeout=180s
