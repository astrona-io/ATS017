#!/usr/bin/env bash
# Reference solution for ats-017-lab-040-02-03. Applied only by `astrona test`.
set -euo pipefail

API="/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute"
WINDOW=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
result=$(kubectl get --raw "${API}?window=${WINDOW}&aggregate=namespace,controller&filter=namespace:%22starfleet%22")

highest=$(printf '%s' "$result" | jq -r '[.data[0] | to_entries[] | select(.key | startswith("starfleet/deployment:"))] | max_by(.value.totalCost) | .key | sub("starfleet/deployment:"; "")')
lowest=$(printf '%s' "$result" | jq -r '[.data[0] | to_entries[] | select(.key | startswith("starfleet/deployment:"))] | min_by(.value.totalCost) | .key | sub("starfleet/deployment:"; "")')

kubectl -n default create configmap cost-scaling-report \
  --from-literal=window="${WINDOW}" \
  --from-literal=highest="${highest}" \
  --from-literal=lowest="${lowest}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n starfleet scale deploy/"${highest}" --replicas=1
kubectl -n starfleet scale deploy/"${lowest}" --replicas=3
kubectl -n starfleet rollout status deploy/"${highest}" --timeout=120s
kubectl -n starfleet rollout status deploy/"${lowest}" --timeout=120s
