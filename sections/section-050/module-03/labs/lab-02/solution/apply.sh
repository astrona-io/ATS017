#!/usr/bin/env bash
# Reference solution for ats-017-lab-050-03-02. Applied only by `astrona test`.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-defaults
spec:
  rules:
    - name: generate-resourcequota
      match:
        any:
          - resources:
              kinds: ["Namespace"]
              selector:
                matchLabels:
                  tenant: "true"
      generate:
        apiVersion: v1
        kind: ResourceQuota
        name: tenant-quota
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          spec:
            hard:
              requests.cpu: 200m
              requests.memory: 256Mi
              limits.memory: 512Mi
              pods: "10"
    - name: generate-limitrange
      match:
        any:
          - resources:
              kinds: ["Namespace"]
              selector:
                matchLabels:
                  tenant: "true"
      generate:
        apiVersion: v1
        kind: LimitRange
        name: tenant-defaults
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          spec:
            limits:
              - type: Container
                defaultRequest:
                  cpu: 25m
                  memory: 32Mi
                default:
                  memory: 64Mi
                max:
                  memory: 128Mi
YAML
