#!/usr/bin/env bash
# Reference solution for ats-017-lab-050-03-01. Applied only by `astrona test`.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-requests-limits
spec:
  background: true
  rules:
    - name: require-requests-and-memory-limit
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["outpost"]
      validate:
        failureAction: Enforce
        message: "Every container needs CPU and memory requests and a memory limit."
        pattern:
          spec:
            containers:
              - resources:
                  requests:
                    cpu: "?*"
                    memory: "?*"
                  limits:
                    memory: "?*"
YAML
