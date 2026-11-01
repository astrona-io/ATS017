#!/usr/bin/env bash
# Starting state for ats-017-lab-040-01-02.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# Prometheus and OpenCost are plumbing, installed with Helm 4.x (chart versions
# pinned below). OpenCost needs several minutes of samples before the
# allocation API returns usable numbers, so the script waits for them and then
# stores a closed time window in the ConfigMap default/report-window. A closed
# window in the past does not change, so the grader can repeat the learner's
# query and get the same numbers.
set -euo pipefail
cd "$(dirname "$0")"

PROMETHEUS_CHART_VERSION="29.40.3"
OPENCOST_CHART_VERSION="2.5.33"
API="/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute"

echo "==> Workloads"
kubectl apply -f manifests/lab-start.yaml

echo "==> Prometheus (chart ${PROMETHEUS_CHART_VERSION})"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update >/dev/null
helm upgrade --install prometheus prometheus-community/prometheus \
  --version "${PROMETHEUS_CHART_VERSION}" \
  --namespace monitoring --create-namespace \
  --values prometheus-values.yaml \
  --wait --timeout 300s

echo "==> OpenCost (chart ${OPENCOST_CHART_VERSION})"
helm repo add opencost https://opencost.github.io/opencost-helm-chart --force-update >/dev/null
helm upgrade --install opencost opencost/opencost \
  --version "${OPENCOST_CHART_VERSION}" \
  --namespace opencost --create-namespace \
  --values opencost-values.yaml \
  --wait --timeout 300s
opencost_ready_at=$(date +%s)

echo "==> Waiting for the workloads"
for namespace_and_name in starfleet/scout starfleet/probe starfleet/shuttle starfleet/crunch starfleet/reports outpost/probe; do
  kubectl -n "${namespace_and_name%%/*}" rollout status "deploy/${namespace_and_name##*/}" --timeout=300s
done

# field_of <json> <object name> <field>: first number of <field> after the object <name>.
field_of() {
  printf '%s' "$1" | sed -n "s|.*\"$2\":{\"name\":\"$2\",||p" | grep -o "\"$3\":[-0-9.e]*" | head -1 | cut -d: -f2
}
# at_least <value> <minimum>: succeeds when both are numbers and value >= minimum.
at_least() {
  awk -v value="${1:-}" -v minimum="$2" 'BEGIN { exit !(value != "" && value + 0 >= minimum + 0) }'
}

echo "==> Waiting for OpenCost to return costs for a closed six-minute window of every Deployment"
for _ in $(seq 1 120); do
  now=$(date +%s)
  start=$((now - 480))
  end=$((now - 120))
  # The window must start after OpenCost had time to collect its first samples.
  if [ "$start" -ge $((opencost_ready_at + 240)) ]; then
    result=$(kubectl get --raw "${API}?window=${start},${end}&aggregate=namespace,controller" 2>/dev/null || true)
    ready=true
    for controller in starfleet/deployment:scout starfleet/deployment:probe starfleet/deployment:shuttle starfleet/deployment:crunch starfleet/deployment:reports outpost/deployment:probe; do
      at_least "$(field_of "$result" "$controller" minutes)" 5 || ready=false
      at_least "$(field_of "$result" "$controller" totalCost)" 0.00001 || ready=false
    done
    if [ "$ready" = true ]; then
      kubectl -n default create configmap report-window \
        --from-literal=window="${start},${end}" \
        --from-literal=start="${start}" \
        --from-literal=end="${end}" \
        --dry-run=client -o yaml | kubectl apply -f -
      echo "==> Report window: ${start},${end}"
      echo "==> Lab ats-017-lab-040-01-02 ready."
      exit 0
    fi
  fi
  sleep 20
done
echo "OpenCost returned no usable costs in time" >&2
exit 1
