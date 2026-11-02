#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-050-03-01.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# Kyverno is installed with Helm 4.x (kyverno/kyverno 3.9.2, Kyverno v1.19.2).
# outpost/probe runs without resources. No policy exists yet.
set -euo pipefail
cd "$(dirname "$0")"

KYVERNO_CHART_VERSION="3.9.2"

echo "==> Namespaces and probe"
kubectl create namespace starfleet --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace outpost --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: outpost
  labels:
    app: probe
spec:
  replicas: 1
  selector:
    matchLabels:
      app: probe
  template:
    metadata:
      labels:
        app: probe
    spec:
      containers:
        - name: probe
          image: mccutchen/go-httpbin:2.25.0
YAML

echo "==> Kyverno (chart ${KYVERNO_CHART_VERSION})"
helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update >/dev/null
helm upgrade --install kyverno kyverno/kyverno \
  --version "${KYVERNO_CHART_VERSION}" \
  --namespace kyverno --create-namespace \
  --values kyverno-values.yaml \
  --wait --timeout 420s

kubectl -n outpost rollout status deploy/probe --timeout=240s
echo "==> Lab ats-017-lab-050-03-01 ready."
