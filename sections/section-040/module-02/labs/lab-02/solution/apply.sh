#!/usr/bin/env bash
# Reference solution for ats-017-lab-040-02-02. Applied only by `astrona test`.
set -euo pipefail

kubectl -n starfleet set resources deploy/scout-overprovisioned \
  --requests=cpu=50m,memory=64Mi
kubectl -n starfleet rollout status deploy/scout-overprovisioned --timeout=120s
