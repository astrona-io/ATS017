#!/usr/bin/env bash
# Reference end state; never invoked by bootstrap.
set -euo pipefail
cd "$(dirname "$0")"
source ../validation/common.sh
kubectl apply -f configmap-custom-pricing-model.yaml
kubectl -n opencost rollout restart deployment/opencost
kubectl -n opencost rollout status deployment/opencost --timeout=180s
for attempt in $(seq 1 60); do
  if bash ../validation/validate-pricing-active.sh >/dev/null 2>&1; then break; fi
  sleep 5
done
bash ../validation/validate-pricing-active.sh
mkdir -p "$RESULT_DIR"
window=$(kubectl -n default get configmap cost-report-window -o jsonpath='{.data.window}')
kubectl cost namespace --opencost --use-proxy --historical --window "$window" \
  --idle=false --show-efficiency=false > "$RESULT_DIR/namespace-cost.txt"
kubectl get --raw "${PROMETHEUS_API}/query?query=kube_pod_info%7Bnamespace%3D%22starfleet%22%7D" > "$RESULT_DIR/pods.json"
kubectl get --raw "${PROMETHEUS_API}/targets" | jq -er '
  .data.activeTargets[] | select(.labels.job == "probe-broken" and .health == "down") | .lastError
' > "$RESULT_DIR/target-error.txt"
