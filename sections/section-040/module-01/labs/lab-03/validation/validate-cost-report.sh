#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
[ -s "$RESULT_DIR/namespace-cost.txt" ] || fail 'cost-report: save the plugin table'
window=$(kubectl -n default get configmap cost-report-window -o jsonpath='{.data.window}')
baseline=$(kubectl -n default get configmap cost-review-baseline -o json)
[ "$window" = "$(jq -r '.data.window' <<<"$baseline")" ] || fail 'cost-report: keep the supplied window unchanged'
for workload in starfleet/scout starfleet/probe outpost/scout; do
  key="${workload%%/*}-${workload##*/}"
  original_spec=$(jq -r --arg key "$key" '.data[$key]' <<<"$baseline")
  kubectl -n "${workload%%/*}" get deployment "${workload##*/}" -o json \
    | jq -e --argjson original "$original_spec" '.spec == $original' >/dev/null \
    || fail 'cost-report: keep the workload specifications unchanged'
done
allocation=$(kubectl get --raw "${OPENCOST_API}/allocation/compute?window=${window}&aggregate=namespace&accumulate=true&idle=false")
jq -e '.data[0].starfleet.totalCost > 0 and .data[0].outpost.totalCost > 0' <<<"$allocation" >/dev/null \
  || fail 'cost-report: the live API has no tenant costs for this window'
expected=$(mktemp)
actual=$(mktemp)
trap 'rm -f "$expected" "$actual"' EXIT
# The closed window makes a second API-backed plugin query reproducible.
kubectl cost namespace --opencost --use-proxy --historical --window "$window" \
  --idle=false --show-efficiency=false > "$expected"
normalize() { tr -d '\r' < "$1" | sed 's/[[:space:]]//g' | LC_ALL=C sort; }
normalize "$expected" > "$actual"
normalize "$RESULT_DIR/namespace-cost.txt" > "$expected"
cmp -s "$actual" "$expected" || fail 'cost-report: save the specified plugin report for the stored window'
echo 'PASS: cost-report'
