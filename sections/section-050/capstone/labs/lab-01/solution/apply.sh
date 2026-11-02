#!/usr/bin/env bash
# Reference solution for ats-017-capstone-050. Applied only by `astrona test`.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: platform-high
value: 100000
preemptionPolicy: PreemptLowerPriority
description: Critical platform workloads
---
apiVersion: v1
kind: LimitRange
metadata:
  name: outpost-defaults
  namespace: outpost
spec:
  limits:
    - type: Container
      defaultRequest:
        memory: 32Mi
      default:
        memory: 64Mi
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: outpost-no-platform-high
  namespace: outpost
spec:
  hard:
    pods: "0"
  scopeSelector:
    matchExpressions:
      - scopeName: PriorityClass
        operator: In
        values: ["platform-high"]
YAML

kubectl -n starfleet patch deploy scout-critical --type merge \
  -p '{"spec":{"template":{"spec":{"priorityClassName":"platform-high"}}}}'
# The batch-worker ReplicaSet backs off after rejected pods. Restart it so the
# new pods get the LimitRange defaults without waiting for the back-off.
kubectl -n outpost rollout restart deploy/batch-worker
