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
# kubectl wait cannot take a filter expression inside --for=jsonpath, so poll.
# Envoy Gateway keeps the status entry of the old parentRef (listener web,
# Accepted=False) next to the new one, so read only the entry for listener http.
for route in team-route relay; do
  for attempt in $(seq 1 36); do
    conditions=$(kubectl -n outpost get httproute "$route" \
      -o jsonpath='{range .status.parents[?(@.parentRef.sectionName=="http")].conditions[*]}{.type}={.status}{" "}{end}')
    case "$conditions" in
      *"Accepted=True "*"ResolvedRefs=True "*|*"ResolvedRefs=True "*"Accepted=True "*) break ;;
    esac
    [ "$attempt" -eq 36 ] && { echo "httproute/$route is not Accepted and ResolvedRefs: $conditions" >&2; exit 1; }
    sleep 5
  done
done
# The route status turns Accepted a moment before Envoy serves it, so send
# the default request through the Gateway until it answers.
gateway_address=$(kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{.status.addresses[0].value}')
for attempt in $(seq 1 36); do
  if kubectl -n starfleet exec deploy/shuttle -- curl --fail --silent --max-time 8 \
    -H 'Host: team.starfleet.example' "http://$gateway_address/" >/dev/null; then
    break
  fi
  [ "$attempt" -eq 36 ] && { echo "the Gateway does not answer for team.starfleet.example" >&2; exit 1; }
  sleep 5
done
