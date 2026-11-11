#!/usr/bin/env bash
# Use a closed allocation window and prove a replica-only change.
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for attempt in $(seq 1 36); do
  end=$(( $(date -u +%s) - 180 )); start=$((end - 300))
  window="${start},${end}"
  kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=${window}&aggregate=namespace,controller&filter=namespace:%22starfleet%22" > "$work/allocation.json"
  jq '[.data[0] | to_entries[] | select(.key | startswith("starfleet/deployment:")) | {deployment: (.key|split(":")[1]),cost:.value.totalCost}] | sort_by(.cost)' "$work/allocation.json" > "$work/ranked.json"
  if jq -e 'length>=2 and all(.[]; (.cost|type=="number") and .cost>0)' "$work/ranked.json" >/dev/null; then break; fi
  sleep 10
done
jq -e 'length>=2 and all(.[]; (.cost|type=="number") and .cost>0)' "$work/ranked.json" >/dev/null
highest=$(jq -r 'last.deployment' "$work/ranked.json")
kubectl -n starfleet get deployment "$highest" -o json > "$work/before.json"
original=$(jq -r '.spec.replicas' "$work/before.json")
kubectl -n starfleet scale deployment "$highest" --replicas=$((original + 1))
kubectl -n starfleet rollout status deployment/"$highest" --timeout=120s
kubectl -n starfleet get deployment "$highest" -o json > "$work/after.json"
python3 - "$work/before.json" "$work/after.json" <<'CHECK'
import json, sys
before, after=(json.load(open(p)) for p in sys.argv[1:])
assert before['metadata']['uid']==after['metadata']['uid']
assert before['spec']['template']==after['spec']['template']
assert after['spec']['replicas']==before['spec']['replicas']+1
assert after['status']['availableReplicas']==after['spec']['replicas']
CHECK
kubectl -n starfleet scale deployment "$highest" --replicas="$original"
kubectl -n starfleet rollout status deployment/"$highest" --timeout=120s
echo 'PASS: cost ranking uses numeric Deployment allocations and scaling preserves the pod template'
