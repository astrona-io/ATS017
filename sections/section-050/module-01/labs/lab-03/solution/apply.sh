#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
kubectl apply -f quotas.yaml
kubectl -n pipeline-shuttle scale deployment/cache-reader --replicas=0
kubectl -n pipeline-shuttle wait --for=delete pod -l app=cache-reader --timeout=180s
kubectl -n pipeline-shuttle delete pvc pipeline-cache --ignore-not-found --timeout=180s
