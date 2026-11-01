#!/usr/bin/env bash
# Reference solution for ats-017-capstone-030. Applied only by `astrona test`.
set -euo pipefail

kubectl -n starfleet set resources deployment/scout \
  --requests=cpu=50m,memory=32Mi --limits=memory=64Mi
kubectl -n starfleet rollout status deployment/scout --timeout=180s

kubectl apply -f - <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: scout
  namespace: starfleet
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scout
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
YAML
