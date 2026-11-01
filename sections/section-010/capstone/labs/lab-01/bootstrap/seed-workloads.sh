#!/usr/bin/env bash
# Creates the starting state for ats-017-capstone-010.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
set -euo pipefail
cd "$(dirname "$0")"

workers=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | sort)
[ "$(echo "$workers" | grep -c .)" -eq 2 ] || { echo "expected 2 worker nodes" >&2; exit 1; }
zone_a_node=$(echo "$workers" | sed -n 1p)
zone_b_node=$(echo "$workers" | sed -n 2p)

echo "==> Node labels"
kubectl label node "$zone_a_node" topology.kubernetes.io/zone=zone-a disktype=ssd --overwrite
kubectl label node "$zone_b_node" topology.kubernetes.io/zone=zone-b --overwrite

echo "==> Workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl -n starfleet rollout status deploy/shuttle --timeout=300s
kubectl -n starfleet rollout status deploy/scout --timeout=300s

echo "==> Waiting for the FailedScheduling event of probe"
for _ in $(seq 1 30); do
  kubectl -n outpost get events --field-selector reason=FailedScheduling 2>/dev/null | grep -q . && break
  sleep 2
done
kubectl -n outpost get pods

echo "==> Lab ats-017-capstone-010 ready."
