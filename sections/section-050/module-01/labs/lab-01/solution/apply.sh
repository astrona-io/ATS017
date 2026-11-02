#!/usr/bin/env bash
# Reference solution for ats-017-lab-050-01-01. Applied only by `astrona test`.
# Four replicas at 100m each fit the 500m quota. The quota stays as it is.
set -euo pipefail

kubectl -n outpost set resources deployment/probe --requests=cpu=100m
kubectl -n outpost rollout status deployment/probe --timeout=180s
