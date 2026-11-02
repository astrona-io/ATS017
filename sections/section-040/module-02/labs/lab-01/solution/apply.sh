#!/usr/bin/env bash
# Reference solution for ats-017-lab-040-02-01. Applied only by `astrona test`.
set -euo pipefail

API="/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute"
window=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
result=$(kubectl get --raw "${API}?window=${window}&aggregate=label:team&filter=namespace:%22starfleet%22,%22outpost%22")

field_of() {
  printf '%s' "$1" | sed -n "s|.*\"$2\":{\"name\":\"$2\",||p" | grep -o "\"$3\":[-0-9.e]*" | head -1 | cut -d: -f2
}

# Record the cost per team for the stored window.
kubectl -n default create configmap team-cost-report \
  --from-literal=window="${window}" \
  --from-literal=navigation="$(field_of "$result" navigation totalCost)" \
  --from-literal=research="$(field_of "$result" research totalCost)" \
  --from-literal=unallocated="$(field_of "$result" __unallocated__ totalCost)" \
  --dry-run=client -o yaml | kubectl apply -f -

# Add the missing label to the pod template, so the new pods carry it.
kubectl -n outpost patch deploy archive --type merge \
  -p '{"spec":{"template":{"metadata":{"labels":{"team":"operations"}}}}}'
kubectl -n outpost rollout status deploy/archive --timeout=120s
