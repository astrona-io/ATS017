#!/usr/bin/env bash
# Generate real CPU load and read the live HPA and Deployment status.
set -euo pipefail
cd "$(dirname "$0")"
python3 check.py hpa
kubectl -n starfleet rollout status deploy/shuttle --timeout=120s >/dev/null
kubectl -n starfleet exec deploy/shuttle -- sh -c \
  'for worker in 1 2 3 4; do timeout 170 curl -s -o /dev/null -X POST "http://scout/token?[1-5000000]" & done; wait' >/dev/null 2>&1 &
load_pid=$!
trap 'kill "$load_pid" 2>/dev/null || true; wait "$load_pid" 2>/dev/null || true' EXIT
for attempt in $(seq 1 40); do
  utilization=$(kubectl -n starfleet get hpa scout -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')
  active=$(kubectl -n starfleet get hpa scout -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}')
  replicas=$(kubectl -n starfleet get deployment scout -o jsonpath='{.status.readyReplicas}')
  if [ "$active" = True ] && [ "${utilization:-0}" -gt 60 ] && [ "${replicas:-0}" -ge 2 ]; then
    echo 'PASS: hpa scales scout to at least two Ready replicas under CPU load'
    exit 0
  fi
  sleep 5
done
echo 'FAIL: hpa did not report CPU utilization above 60 percent and two Ready replicas under load'
exit 1
