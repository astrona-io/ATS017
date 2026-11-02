#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-050-02-02.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# outpost runs two beacon pods that use the PriorityClass platform-high.
# No ResourceQuota exists yet.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Namespaces, PriorityClass and beacon"
kubectl apply -f manifests/lab-start.yaml
kubectl -n outpost rollout status deploy/beacon --timeout=240s
kubectl -n outpost get pods

echo "==> Lab ats-017-lab-050-02-02 ready."
