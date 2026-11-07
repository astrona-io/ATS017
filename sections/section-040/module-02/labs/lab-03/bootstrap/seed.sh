#!/usr/bin/env bash
# Starting state for ats-017-lab-040-02-03.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# Prometheus and OpenCost are plumbing, installed with Helm 4.x (chart versions
# pinned below). OpenCost needs several minutes of samples before the
# allocation API returns usable numbers, so the script waits for them and then
# stores a closed time window in the ConfigMap default/report-window. A closed
# window in the past does not change, so the learner and the grader see the
# same ranking. The script only accepts a window in which relay is clearly the
# most expensive Deployment and beacon is clearly the least expensive one.
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
for namespace_and_name in starfleet/scout starfleet/relay starfleet/beacon starfleet/shuttle; do
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
# ratio_at_least <a> <b> <factor>: succeeds when a >= b * factor and both are numbers.
ratio_at_least() {
  awk -v a="${1:-}" -v b="${2:-}" -v factor="$3" 'BEGIN { exit !(a != "" && b != "" && a + 0 >= (b + 0) * factor) }'
}

echo "==> Waiting for OpenCost to rank the Deployments for a closed window of about three minutes"
for _ in $(seq 1 120); do
  now=$(date +%s)
  start=$((now - 360))
  end=$((now - 150))
  # The window must start after OpenCost had time to collect its first samples.
  if [ "$start" -ge $((opencost_ready_at + 60)) ]; then
    result=$(kubectl get --raw "${API}?window=${start},${end}&aggregate=namespace,controller" 2>/dev/null || true)
    ready=true
    for controller in starfleet/deployment:scout starfleet/deployment:relay starfleet/deployment:beacon starfleet/deployment:shuttle; do
      at_least "$(field_of "$result" "$controller" minutes)" 2.5 || ready=false
      at_least "$(field_of "$result" "$controller" totalCost)" 0.00001 || ready=false
    done
    relay=$(field_of "$result" starfleet/deployment:relay totalCost)
    scout=$(field_of "$result" starfleet/deployment:scout totalCost)
    shuttle=$(field_of "$result" starfleet/deployment:shuttle totalCost)
    beacon=$(field_of "$result" starfleet/deployment:beacon totalCost)
    # relay must cost at least twice as much as every other Deployment, and
    # every other Deployment must cost at least 1.3 times beacon.
    ratio_at_least "$relay" "$scout" 2 || ready=false
    ratio_at_least "$relay" "$shuttle" 2 || ready=false
    ratio_at_least "$scout" "$beacon" 1.3 || ready=false
    ratio_at_least "$shuttle" "$beacon" 1.3 || ready=false
    if [ "$ready" = true ]; then
      kubectl -n default create configmap report-window \
        --from-literal=window="${start},${end}" \
        --from-literal=start="${start}" \
        --from-literal=end="${end}" \
        --dry-run=client -o yaml | kubectl apply -f -
      echo "==> Report window: ${start},${end}"
      echo "==> Lab ats-017-lab-040-02-03 ready."
      exit 0
    fi
  fi
  sleep 20
done
echo "OpenCost returned no usable ranking in time" >&2
exit 1
