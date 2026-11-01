#!/usr/bin/env bash
# Grading for ats-017-lab-040-01-02. Checks:
#   1. the ConfigMap default/least-efficient has the key controller
#   2. the named Deployment is one of the Deployments that OpenCost reports for
#      the namespace starfleet in the closed window stored in default/report-window
#   3. its totalEfficiency is the lowest of those Deployments (a value up to 1.5
#      times the lowest, plus 0.005, is accepted, so rounding does not decide)
#   4. the workloads were not changed to fake a result
set -u

API="/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute"
fail() { echo "FAIL: $*"; exit 1; }

field_of() {
  printf '%s' "$1" | sed -n "s|.*\"$2\":{\"name\":\"$2\",||p" | grep -o "\"$3\":[-0-9.e]*" | head -1 | cut -d: -f2
}

# --- 1. the ConfigMap ---------------------------------------------------------------
kubectl -n default get configmap least-efficient >/dev/null 2>&1 \
  || fail "the ConfigMap least-efficient does not exist in the namespace default"
answer=$(kubectl -n default get configmap least-efficient -o jsonpath='{.data.controller}' 2>/dev/null)
[ -n "$answer" ] || fail "the key controller is missing from the ConfigMap least-efficient"
answer="${answer#starfleet/}"
answer="${answer#deployment:}"

# --- 2. the OpenCost data -------------------------------------------------------------
window=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}' 2>/dev/null)
[ -n "$window" ] || fail "the ConfigMap report-window is missing. Do not delete it"
result=$(kubectl get --raw "${API}?window=${window}&aggregate=namespace,controller" 2>/dev/null)
[ -n "$result" ] || fail "OpenCost did not answer. Check the pod in the namespace opencost"

names=$(printf '%s' "$result" | grep -o '"starfleet/deployment:[a-z0-9-]*":{"name"' | cut -d'"' -f2)
[ -n "$names" ] || fail "OpenCost returned no Deployments for the namespace starfleet"
lowest_value=""
lowest_name=""
for controller in $names; do
  value=$(field_of "$result" "$controller" totalEfficiency)
  [ -n "$value" ] || continue
  if [ -z "$lowest_value" ] || awk -v a="$value" -v b="$lowest_value" 'BEGIN { exit !(a + 0 < b + 0) }'; then
    lowest_value="$value"
    lowest_name="${controller#starfleet/deployment:}"
  fi
done
[ -n "$lowest_name" ] || fail "OpenCost returned no efficiency for the Deployments in starfleet"

answer_value=$(field_of "$result" "starfleet/deployment:${answer}" totalEfficiency)
[ -n "$answer_value" ] || fail "'${answer}' is not a Deployment in the namespace starfleet that OpenCost reports. Store only the Deployment name"
echo "OK: ${answer} is a Deployment in starfleet (totalEfficiency ${answer_value})"

# --- 3. the lowest efficiency -----------------------------------------------------------
awk -v answer="$answer_value" -v lowest="$lowest_value" 'BEGIN { exit !(answer + 0 <= lowest * 1.5 + 0.005) }' \
  || fail "${answer} has a totalEfficiency of ${answer_value}, but ${lowest_name} has ${lowest_value}. Sort by totalEfficiency (usage divided by request), not by cost"
echo "OK: ${answer} has the lowest totalEfficiency"

# --- 4. nothing else was changed ----------------------------------------------------
reports_cpu=$(kubectl -n starfleet get deploy reports -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
[ "$reports_cpu" = "300m" ] || fail "the CPU request of reports changed to '${reports_cpu}'. Find the workload, do not change it yet"
crunch_cpu=$(kubectl -n starfleet get deploy crunch -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
[ "$crunch_cpu" = "500m" ] || fail "the CPU request of crunch changed to '${crunch_cpu}'. Find the workload, do not change it"
echo "OK: the workloads are unchanged"

echo "PASS: ${answer} is the least efficient Deployment in starfleet"
exit 0
