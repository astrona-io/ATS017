#!/usr/bin/env bash
# Reference solution for ats-017-lab-010-01-01. Applied only by `astrona test`.
set -euo pipefail

kubectl -n starfleet set resources deployment/scout \
  --requests=cpu=50m,memory=128Mi \
  --limits=cpu=200m,memory=192Mi
kubectl -n starfleet rollout status deployment/scout --timeout=180s
