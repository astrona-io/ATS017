#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Keep in step with solution.md.
set -euo pipefail

# A claim's accessModes cannot be edited, so stop the consumer, replace the claim
# and start the consumer again.
kubectl -n starfleet scale deploy/scout --replicas=0
kubectl -n starfleet wait --for=delete pod -l app=scout --timeout=120s
kubectl -n starfleet delete pvc scout-data

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: scout-data
  namespace: starfleet
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 64Mi
YAML

kubectl -n starfleet scale deploy/scout --replicas=1
kubectl -n starfleet rollout status deploy/scout --timeout=180s
