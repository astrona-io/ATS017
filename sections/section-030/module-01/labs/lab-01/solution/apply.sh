#!/usr/bin/env bash
# Reference solution for ats-017-lab-030-01-01. Applied only by `astrona test`.
set -euo pipefail

kubectl -n starfleet set resources deployment/scout --requests=cpu=100m
kubectl -n starfleet rollout status deployment/scout --timeout=180s
