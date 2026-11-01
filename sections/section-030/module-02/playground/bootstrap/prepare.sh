#!/usr/bin/env bash
# Starting state for ats-017-playground-030-02.
# astrona runs this script with KUBECONFIG pointed at the playground cluster.
# Prometheus is plumbing: a small install of the prometheus-community chart
# (chart 29.40.3, Prometheus v3.15.1) whose default scrape jobs include the
# kubelet's cAdvisor metrics. Helm 4.x is used for the install only.
set -euo pipefail
cd "$(dirname "$0")"

PROMETHEUS_CHART_VERSION="29.40.3"

echo "==> Workloads"
kubectl apply -f ../manifests/lab-start.yaml

echo "==> Prometheus (chart ${PROMETHEUS_CHART_VERSION})"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update >/dev/null
helm upgrade --install prometheus prometheus-community/prometheus \
  --version "${PROMETHEUS_CHART_VERSION}" \
  --namespace monitoring --create-namespace \
  --set alertmanager.enabled=false \
  --set prometheus-pushgateway.enabled=false \
  --set prometheus-node-exporter.enabled=false \
  --set kube-state-metrics.enabled=false \
  --set server.persistentVolume.enabled=false \
  --set server.retention=2h \
  --set server.global.scrape_interval=15s \
  --wait --timeout 300s

echo "==> Waiting for the workloads"
for name in scout-overprovisioned scout-underprovisioned shuttle; do
  kubectl -n starfleet rollout status "deploy/${name}" --timeout=300s
done

echo "==> Waiting for the Metrics API"
for _ in $(seq 1 60); do
  available=$(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || true)
  [ "$available" = "True" ] && break
  sleep 3
done

echo "==> Playground ready."
