#!/usr/bin/env bash
# Reference solution for ats-017-lab-050-02-02. Applied only by `astrona test`.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: outpost-high
  namespace: outpost
spec:
  hard:
    pods: "2"
  scopeSelector:
    matchExpressions:
      - scopeName: PriorityClass
        operator: In
        values: ["platform-high"]
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: outpost-no-besteffort
  namespace: outpost
spec:
  hard:
    pods: "0"
  scopes: ["BestEffort"]
YAML
