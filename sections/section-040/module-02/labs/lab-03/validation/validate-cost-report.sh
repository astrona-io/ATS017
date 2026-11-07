#!/usr/bin/env bash
# Grading for ats-017-lab-040-02-03, part 1. Checks the ConfigMap
# default/cost-scaling-report:
#   1. it exists and its key window is exactly the window of report-window
#   2. its key highest names the Deployment with the highest totalCost in that
#      window, and its key lowest names the one with the lowest totalCost
# The bootstrap script only closed the window after OpenCost ranked relay far
# above every other Deployment and beacon far below, so the grader knows the
# answer without calling OpenCost again. A closed window never changes.
set -u

fail() { echo "FAIL: $*"; exit 1; }

expected_highest=relay
expected_lowest=beacon

kubectl -n default get configmap cost-scaling-report >/dev/null 2>&1 \
  || fail "the ConfigMap cost-scaling-report does not exist in the namespace default"

expected_window=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}' 2>/dev/null)
window=$(kubectl -n default get configmap cost-scaling-report -o jsonpath='{.data.window}' 2>/dev/null)
[ -n "$window" ] || fail "cost-scaling-report has no key window"
[ "$window" = "$expected_window" ] \
  || fail "cost-scaling-report has window '${window}', expected the value of report-window: '${expected_window}'"
echo "OK: the report uses the window ${window}"

highest=$(kubectl -n default get configmap cost-scaling-report -o jsonpath='{.data.highest}' 2>/dev/null)
lowest=$(kubectl -n default get configmap cost-scaling-report -o jsonpath='{.data.lowest}' 2>/dev/null)
[ -n "$highest" ] || fail "cost-scaling-report has no key highest"
[ -n "$lowest" ] || fail "cost-scaling-report has no key lowest"
[ "$highest" = "$expected_highest" ] \
  || fail "cost-scaling-report names '${highest}' as the most expensive Deployment. Sort the controllers of starfleet by totalCost and take the last one"
[ "$lowest" = "$expected_lowest" ] \
  || fail "cost-scaling-report names '${lowest}' as the least expensive Deployment. Sort the controllers of starfleet by totalCost and take the first one"
echo "OK: ${highest} is the most expensive and ${lowest} the least expensive Deployment"

echo "PASS: cost-scaling-report names the right Deployments"
exit 0
