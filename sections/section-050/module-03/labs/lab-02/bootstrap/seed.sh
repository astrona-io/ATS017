#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-050-03-02.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# Kyverno is installed with Helm 4.x (kyverno/kyverno 3.9.2, Kyverno v1.19.2).
# No policy and no tenant namespace exists yet.
set -euo pipefail
cd "$(dirname "$0")"

KYVERNO_CHART_VERSION="3.9.2"

echo "==> Kyverno (chart ${KYVERNO_CHART_VERSION})"
helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update >/dev/null
helm upgrade --install kyverno kyverno/kyverno \
  --version "${KYVERNO_CHART_VERSION}" \
  --namespace kyverno --create-namespace \
  --values kyverno-values.yaml \
  --wait --timeout 420s

kubectl -n kyverno get pods
echo "==> Lab ats-017-lab-050-03-02 ready."
