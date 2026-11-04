#!/usr/bin/env bash
# Seed the environment only; every graded result remains absent or unchanged.
set -euo pipefail
cd "$(dirname "$0")"
bash ./install-cost-plugin.sh
mkdir -p /tmp/cnpe-cost-review
rm -f /tmp/cnpe-cost-review/namespace-cost.txt /tmp/cnpe-cost-review/pods.json /tmp/cnpe-cost-review/target-error.txt
kubectl apply -f ../manifests/lab-start.yaml
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update >/dev/null
helm upgrade --install prometheus prometheus-community/prometheus \
  --version 29.40.3 --namespace monitoring --create-namespace \
  --values prometheus-values.yaml --wait --timeout 300s
helm repo add opencost https://opencost.github.io/opencost-helm-chart --force-update >/dev/null
helm upgrade --install opencost opencost/opencost \
  --version 2.5.33 --namespace opencost --create-namespace \
  --values opencost-values.yaml --wait --timeout 300s
for workload in starfleet/scout starfleet/probe outpost/scout; do
  kubectl -n "${workload%%/*}" rollout status "deploy/${workload##*/}" --timeout=180s
done
PROMETHEUS_API=/api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1
OPENCOST_API=/api/v1/namespaces/opencost/services/opencost:9003/proxy
ready_at=$(date +%s)
# Keep waiting until the six-minute window lies after initial collection.
for attempt in $(seq 1 90); do
  now=$(date +%s)
  start=$((now - 480))
  end=$((now - 120))
  if [ "$start" -ge $((ready_at + 240)) ]; then
    allocation=$(kubectl get --raw "${OPENCOST_API}/allocation/compute?window=${start},${end}&aggregate=namespace&accumulate=true&idle=false" 2>/dev/null || true)
    pods=$(kubectl get --raw "${PROMETHEUS_API}/query?query=kube_pod_info%7Bnamespace%3D%22starfleet%22%7D" 2>/dev/null || true)
    targets=$(kubectl get --raw "${PROMETHEUS_API}/targets" 2>/dev/null || true)
    if jq -e '.data[0].starfleet.totalCost > 0 and .data[0].outpost.totalCost > 0' <<<"$allocation" >/dev/null 2>&1 \
      && jq -e '.status == "success" and (.data.result | length > 0)' <<<"$pods" >/dev/null 2>&1 \
      && jq -e 'any(.data.activeTargets[]; .labels.job == "probe-broken" and .health == "down" and (.lastError | length > 0))' <<<"$targets" >/dev/null 2>&1; then
      kubectl -n default create configmap cost-report-window \
        --from-literal=window="${start},${end}" --dry-run=client -o yaml | kubectl apply -f -
      kubectl -n default create configmap cost-review-baseline \
        --from-literal=window="${start},${end}" \
        --from-literal=starfleet-scout="$(kubectl -n starfleet get deployment scout -o json | jq -c '.spec')" \
        --from-literal=starfleet-probe="$(kubectl -n starfleet get deployment probe -o json | jq -c '.spec')" \
        --from-literal=outpost-scout="$(kubectl -n outpost get deployment scout -o json | jq -c '.spec')" \
        --dry-run=client -o yaml | kubectl apply -f -
      echo 'Cost review environment ready; graded files have not been created.'
      exit 0
    fi
  fi
  sleep 15
done
echo 'Cost data, pod metrics, or the deliberate failing target did not become available.' >&2
exit 1
