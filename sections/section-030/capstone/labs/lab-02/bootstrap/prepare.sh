#!/usr/bin/env bash
# Install controllers as plumbing; do not create the student's VPA objects.
set -euo pipefail
cd "$(dirname "$0")"
for tool in kubectl helm python3; do
  command -v "$tool" >/dev/null || { echo "Missing terminal tool: $tool" >&2; exit 1; }
done
helm upgrade --install vpa \
  https://github.com/kubernetes/autoscaler/releases/download/vertical-pod-autoscaler-chart-0.12.0/vertical-pod-autoscaler-0.12.0.tgz \
  --namespace vpa-system --create-namespace \
  -f ../manifests/vpa-values.yaml --wait --wait-for-jobs --timeout 300s
kubectl wait --for=condition=Established crd/verticalpodautoscalers.autoscaling.k8s.io --timeout=120s
kubectl apply -f ../manifests/lab-start.yaml
kubectl -n starfleet rollout status statefulset/probe --timeout=180s
kubectl -n starfleet rollout status deployment/scout --timeout=180s

# Preserve the original Pod identities so a grader can distinguish replacement.
probe_uid=$(kubectl -n starfleet get pod probe-0 -o jsonpath='{.metadata.uid}')
scout_uid=$(kubectl -n starfleet get pods -l app=scout -o jsonpath='{.items[0].metadata.uid}')
kubectl -n kube-system create configmap vpa-lab-start \
  --from-literal=probe="$probe_uid" --from-literal=scout="$scout_uid" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n starfleet rollout status deployment/shuttle --timeout=180s

# Fail clearly if the plumbing cannot serve usage; never seed a recommendation.
for attempt in $(seq 1 60); do
  if kubectl -n starfleet top pod probe-0 >/dev/null 2>&1; then exit 0; fi
  sleep 3
done
echo "Metrics are unavailable; inspect the metrics-server addon" >&2
exit 1
