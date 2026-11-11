#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl apply -f "$DIR/testing/statefulset-probe.yaml"
kubectl -n starfleet rollout status statefulset/probe --timeout=180s
before="$(kubectl -n starfleet get pvc data-probe-1 -o jsonpath='{.metadata.uid}:{.spec.volumeName}')"
claim="$(kubectl -n starfleet get pod probe-1 -o jsonpath='{.spec.volumes[?(@.name=="data")].persistentVolumeClaim.claimName}')"
[[ "$claim" = data-probe-1 ]]
kubectl -n starfleet scale statefulset probe --replicas=1
kubectl -n starfleet wait --for=delete pod/probe-1 --timeout=120s
[[ "$(kubectl -n starfleet get pvc data-probe-1 -o jsonpath='{.status.phase}')" = Bound ]]
kubectl -n starfleet scale statefulset probe --replicas=2
kubectl -n starfleet rollout status statefulset/probe --timeout=180s
after="$(kubectl -n starfleet get pvc data-probe-1 -o jsonpath='{.metadata.uid}:{.spec.volumeName}')"
[[ "$before" = "$after" ]]
echo 'PASS: lesson StatefulSet creates per-replica claims and reuses them after scaling'
