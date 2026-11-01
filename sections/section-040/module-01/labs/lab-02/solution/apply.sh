#!/usr/bin/env bash
# Reference solution for ats-017-lab-040-01-02. Applied only by `astrona test`.
set -euo pipefail

API="/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute"
window=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
result=$(kubectl get --raw "${API}?window=${window}&aggregate=namespace,controller")

field_of() {
  printf '%s' "$1" | sed -n "s|.*\"$2\":{\"name\":\"$2\",||p" | grep -o "\"$3\":[-0-9.e]*" | head -1 | cut -d: -f2
}

# Find the Deployment in starfleet with the lowest totalEfficiency.
lowest_name=""
lowest_value=""
for controller in $(printf '%s' "$result" | grep -o '"starfleet/deployment:[a-z0-9-]*":{"name"' | cut -d'"' -f2); do
  value=$(field_of "$result" "$controller" totalEfficiency)
  if [ -z "$lowest_value" ] || awk -v a="$value" -v b="$lowest_value" 'BEGIN { exit !(a + 0 < b + 0) }'; then
    lowest_value="$value"
    lowest_name="${controller#starfleet/deployment:}"
  fi
done
echo "Least efficient: ${lowest_name} (totalEfficiency ${lowest_value})"

kubectl -n default create configmap least-efficient \
  --from-literal=controller="${lowest_name}" \
  --dry-run=client -o yaml | kubectl apply -f -
