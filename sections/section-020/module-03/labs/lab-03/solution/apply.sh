#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl -n starfleet patch statefulset probe --type=merge -p '{"spec":{"persistentVolumeClaimRetentionPolicy":{"whenScaled":"Retain","whenDeleted":"Retain"}}}'
# Wait for the controller to remove claim owner references before scaling.
for attempt in $(seq 1 60); do
  owners="$(kubectl -n starfleet get pvc data-probe-0 data-probe-1 -o json | python3 -c 'import json,sys; print(sum(len(x["metadata"].get("ownerReferences",[])) for x in json.load(sys.stdin)["items"]))')"
  if [ "$owners" = 0 ]; then exit 0; fi
  sleep 2
done
echo 'Claim owner references did not converge' >&2
exit 1
