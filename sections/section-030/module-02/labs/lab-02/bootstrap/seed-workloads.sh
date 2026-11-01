#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-030-02-02.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# It records the UID of the scout pod in a ConfigMap, so the grader can prove
# that the same pod, not a new one, runs with the new resources.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl -n starfleet rollout status deploy/scout --timeout=300s
kubectl -n starfleet rollout status deploy/shuttle --timeout=300s

echo "==> Recording the scout pod"
uid=$(kubectl -n starfleet get pods -l app=scout -o jsonpath='{.items[0].metadata.uid}')
kubectl -n kube-system create configmap lab-030-02-02-state --from-literal=podUID="$uid" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n starfleet get pods

echo "==> Lab ats-017-lab-030-02-02 ready."
