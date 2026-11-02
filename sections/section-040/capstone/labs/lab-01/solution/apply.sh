#!/usr/bin/env bash
# Reference solution for ats-017-capstone-040. Applied only by `astrona test`.
set -euo pipefail

API="/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute"
window=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
result=$(kubectl get --raw "${API}?window=${window}&aggregate=namespace,controller&filter=namespace:%22starfleet%22,%22outpost%22")

field_of() {
  printf '%s' "$1" | sed -n "s|.*\"$2\":{\"name\":\"$2\",||p" | grep -o "\"$3\":[-0-9.e]*" | head -1 | cut -d: -f2
}
cost_of() { field_of "$result" "$1" totalCost; }
add() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a + b }'; }

# Record the cost per team and the least efficient Deployment for the stored window.
kubectl -n default create configmap cost-report \
  --from-literal=window="${window}" \
  --from-literal=navigation="$(add "$(cost_of starfleet/deployment:scout)" "$(cost_of starfleet/deployment:shuttle)")" \
  --from-literal=operations="$(add "$(cost_of starfleet/deployment:probe)" "$(cost_of outpost/deployment:archive)")" \
  --from-literal=science="$(cost_of starfleet/deployment:analytics)" \
  --from-literal=least-efficient=analytics \
  --dry-run=client -o yaml | kubectl apply -f -

# Label the pod templates that have no team label.
for target in starfleet/probe:operations starfleet/analytics:science outpost/archive:operations; do
  namespace=${target%%/*}; rest=${target#*/}; name=${rest%%:*}; team=${rest##*:}
  kubectl -n "$namespace" patch deploy "$name" --type merge \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"team\":\"${team}\"}}}}}"
done

# Right-size the least efficient Deployment.
kubectl -n starfleet set resources deploy/analytics --requests=cpu=50m,memory=64Mi
for target in starfleet/probe starfleet/analytics outpost/archive; do
  kubectl -n "${target%%/*}" rollout status "deploy/${target##*/}" --timeout=120s
done
