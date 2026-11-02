#!/usr/bin/env bash
# Reference solution for ats-017-lab-050-01-02. Applied only by `astrona test`.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: LimitRange
metadata:
  name: outpost-defaults
  namespace: outpost
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 50m
        memory: 64Mi
      default:
        memory: 128Mi
      max:
        memory: 256Mi
YAML

# The ReplicaSet backs off after failed creates. A new rollout tries at once.
kubectl -n outpost rollout restart deployment/batch-worker
kubectl -n outpost rollout status deployment/batch-worker --timeout=180s
