#!/usr/bin/env bash
# Starting state for ats-017-playground-050-03.
# astrona runs this script with KUBECONFIG pointed at the playground cluster.
# Kyverno is installed with Helm 4.x:
#   - kyverno/kyverno 3.9.2 (Kyverno v1.19.2), one replica of each controller,
#     no cleanup controller
set -euo pipefail
cd "$(dirname "$0")"

KYVERNO_CHART_VERSION="3.9.2"

echo "==> Workloads"
kubectl apply -f ../manifests/lab-start.yaml

echo "==> Kyverno (chart ${KYVERNO_CHART_VERSION})"
helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update >/dev/null
helm upgrade --install kyverno kyverno/kyverno \
  --version "${KYVERNO_CHART_VERSION}" \
  --namespace kyverno --create-namespace \
  --values kyverno-values.yaml \
  --wait --timeout 420s

echo "==> Waiting for the workloads"
for namespace_and_name in starfleet/scout starfleet/shuttle outpost/scout outpost/probe outpost/shuttle; do
  kubectl -n "${namespace_and_name%%/*}" rollout status "deploy/${namespace_and_name##*/}" --timeout=300s
done

echo "==> Playground ready."
