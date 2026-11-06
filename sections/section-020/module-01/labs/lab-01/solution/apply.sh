#!/usr/bin/env bash
# Reference end state. Keep synchronized with solution.yaml and solution.md.
set -euo pipefail
kubectl apply -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: starfleet-gateway
  namespace: starfleet
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              kubernetes.io/metadata.name: outpost
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: team-route
  namespace: outpost
spec:
  parentRefs:
    - name: starfleet-gateway
      namespace: starfleet
      sectionName: http
  hostnames:
    - team.starfleet.example
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: scout
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /
          headers:
            - name: x-version
              value: canary
      backendRefs:
        - name: probe
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: bridge
          port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: relay
  namespace: outpost
spec:
  parentRefs:
    - name: starfleet-gateway
      namespace: starfleet
      sectionName: http
  hostnames:
    - relay.starfleet.example
  rules:
    - backendRefs:
        - name: bridge
          port: 80
          namespace: starfleet
---
apiVersion: gateway.networking.k8s.io/v1
kind: ReferenceGrant
metadata:
  name: allow-outpost-bridge
  namespace: starfleet
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: outpost
  to:
    - group: ''
      kind: Service
      name: bridge
YAML
kubectl -n starfleet wait --for=condition=Programmed gateway/starfleet-gateway --timeout=180s
for route in team-route relay; do
  kubectl -n outpost wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True httproute/"$route" --timeout=180s
  kubectl -n outpost wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'=True httproute/"$route" --timeout=180s
done
