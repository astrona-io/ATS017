#!/usr/bin/env bash
# Reference solution for ats-017-lab-050-02-01. Applied only by `astrona test`.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: platform-high
value: 100000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "Platform workloads that may evict tenant batch pods."
YAML

kubectl -n starfleet patch deployment scout-critical --type merge \
  -p '{"spec":{"template":{"spec":{"priorityClassName":"platform-high"}}}}'
kubectl -n starfleet rollout status deployment/scout-critical --timeout=180s
