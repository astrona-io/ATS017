#!/usr/bin/env bash
# Grading for ats-017-lab-040-01-01. Checks:
#   1. the ConfigMap default/namespace-cost-report exists with the keys window,
#      starfleet and outpost
#   2. the window key equals the window in the ConfigMap default/report-window
#   3. the reported total cost of each namespace is within 15 percent (and at
#      least 0.00002 dollars, because OpenCost rounds to 5 decimals) of the
#      total cost that OpenCost returns now for that closed window
#   4. the workloads were not changed to fake a result
set -u
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

API="/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute"
fail() { echo "FAIL: $*"; exit 1; }

field_of() {
  printf '%s' "$1" | python3 "$SCRIPT_DIR/cost-values.py" field "$2" "$3"
}
is_number() { python3 "$SCRIPT_DIR/cost-values.py" number "$1"; }
within_tolerance() {
  python3 "$SCRIPT_DIR/cost-values.py" within "$1" "$2" 0.00002
}

# --- 1. the ConfigMap ---------------------------------------------------------------
kubectl -n default get configmap namespace-cost-report >/dev/null 2>&1 \
  || fail "the ConfigMap namespace-cost-report does not exist in the namespace default"
report() { kubectl -n default get configmap namespace-cost-report -o jsonpath="{.data.$1}" 2>/dev/null; }

# --- 2. the window --------------------------------------------------------------------
window=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}' 2>/dev/null)
[ -n "$window" ] || fail "the ConfigMap report-window is missing. Do not delete it"
used_window=$(report window)
[ "$used_window" = "$window" ] || fail "the key window is '${used_window}', expected '${window}'. Query the window from the ConfigMap report-window and store it in the key window"
echo "OK: the report names the window ${window}"

# --- 3. the costs ---------------------------------------------------------------------
result=$(kubectl get --raw "${API}?window=${window}&aggregate=namespace" 2>/dev/null)
[ -n "$result" ] || fail "OpenCost did not answer. Check the pod in the namespace opencost"
for namespace in starfleet outpost; do
  expected=$(field_of "$result" "$namespace" totalCost)
  [ -n "$expected" ] || fail "OpenCost returned no cost for the namespace ${namespace}"
  reported=$(report "$namespace")
  [ -n "$reported" ] || fail "the key ${namespace} is missing from the ConfigMap namespace-cost-report"
  is_number "$reported" || fail "the key ${namespace} is '${reported}'. Store only the number from the field totalCost"
  within_tolerance "$reported" "$expected" \
    || fail "the cost of ${namespace} is ${reported}, but OpenCost returns ${expected} for the window ${window}. Use the field totalCost and the aggregate namespace"
  echo "OK: ${namespace} total cost ${reported} (OpenCost: ${expected})"
done

# --- 4. nothing else was changed ----------------------------------------------------
cpu=$(kubectl -n outpost get deploy probe -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
[ "$cpu" = "500m" ] || fail "the CPU request of the probe in outpost changed to '${cpu}'. Report the cost, do not change the workloads"
cpu=$(kubectl -n starfleet get deploy scout -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
[ "$cpu" = "100m" ] || fail "the CPU request of the scout in starfleet changed to '${cpu}'. Report the cost, do not change the workloads"
echo "OK: the workloads are unchanged"

echo "PASS: the namespace costs match OpenCost"
exit 0
