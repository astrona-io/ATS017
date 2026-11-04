#!/usr/bin/env bash
# Starting state for ats-017-playground-040-01.
# astrona runs this script with KUBECONFIG pointed at the playground cluster.
# Prometheus and OpenCost are plumbing, installed with Helm 4.x:
#   - prometheus-community/prometheus 29.40.3 (Prometheus v3.15.1) with
#     kube-state-metrics, no Alertmanager, no Pushgateway, no node-exporter
#   - opencost/opencost 2.5.33 (OpenCost 1.121.3) with its default price list
set -euo pipefail
cd "$(dirname "$0")"

PROMETHEUS_CHART_VERSION="29.40.3"
OPENCOST_CHART_VERSION="2.5.33"

bash ./install-cost-plugin.sh

echo "==> Workloads"
kubectl apply -f ../manifests/lab-start.yaml

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

echo "==> Waiting for the workloads"
for namespace_and_name in starfleet/scout starfleet/probe starfleet/shuttle starfleet/scout-busy outpost/probe; do
  kubectl -n "${namespace_and_name%%/*}" rollout status "deploy/${namespace_and_name##*/}" --timeout=300s
done

echo "==> Playground ready."
