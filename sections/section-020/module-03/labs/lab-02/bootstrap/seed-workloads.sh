#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-020-03-02.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# Nothing the task asks for is created: the volume keeps the Delete policy and
# standard stays the default class.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Storage and workloads"
kubectl apply -f manifests/lab-start.yaml
kubectl -n starfleet wait --for=condition=Ready pod/probe-storage --timeout=300s

echo "==> Saving the file the task must keep"
kubectl -n starfleet exec probe-storage -- sh -c 'echo saved-by-probe > /data/message.txt'
kubectl -n starfleet exec probe-storage -- cat /data/message.txt

echo "==> Lab ats-017-lab-020-03-02 ready."
