#!/usr/bin/env bash
# Give the two workers zone labels, mark one as having an SSD, and reserve the
# zone-b worker for the `outpost` tenant with a NoSchedule taint.
set -euo pipefail

workers=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | sort)
worker_count=$(echo "$workers" | grep -c .)
if [ "$worker_count" -ne 2 ]; then
  echo "expected 2 worker nodes, found $worker_count" >&2
  exit 1
fi
zone_a_node=$(echo "$workers" | sed -n 1p)
zone_b_node=$(echo "$workers" | sed -n 2p)

kubectl label node "$zone_a_node" topology.kubernetes.io/zone=zone-a disktype=ssd --overwrite
kubectl label node "$zone_b_node" topology.kubernetes.io/zone=zone-b --overwrite
kubectl taint node "$zone_b_node" dedicated=outpost:NoSchedule --overwrite
