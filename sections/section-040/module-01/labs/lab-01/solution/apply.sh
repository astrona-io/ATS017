#!/usr/bin/env bash
# Reference solution for ats-017-lab-040-01-01. Applied only by `astrona test`.
set -euo pipefail

API="/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute"
window=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
result=$(kubectl get --raw "${API}?window=${window}&aggregate=namespace")

field_of() {
  printf '%s' "$1" | sed -n "s|.*\"$2\":{\"name\":\"$2\",||p" | grep -o "\"$3\":[-0-9.e]*" | head -1 | cut -d: -f2
}

kubectl -n default create configmap namespace-cost-report \
  --from-literal=window="${window}" \
  --from-literal=starfleet="$(field_of "$result" starfleet totalCost)" \
  --from-literal=outpost="$(field_of "$result" outpost totalCost)" \
  --dry-run=client -o yaml | kubectl apply -f -
