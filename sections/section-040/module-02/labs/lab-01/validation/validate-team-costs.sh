#!/usr/bin/env bash
# Grading for ats-017-lab-040-02-01. Checks:
#   1. the Deployment outpost/archive carries team=operations on its pod
#      template, and its running pods carry the label too
#   2. the live OpenCost API (aggregate=pod,label:team, from the start of the
#      current archive pod until now) lists the current archive pod under the
#      team operations and not under __unallocated__. OpenCost needs about five
#      minutes after a pod starts, so the script retries for up to 8 minutes
#   3. the ConfigMap default/team-cost-report names the stored window and the
#      cost of navigation, research and the unallocated bucket for it, each
#      within 15 percent (at least 0.00003 dollars, because OpenCost rounds to
#      5 decimals) of what OpenCost returns for that closed window
#   4. the requests of the workloads were not changed to fake a result
set -u
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

API="/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute"
fail() { echo "FAIL: $*"; exit 1; }

field_of() {
  printf '%s' "$1" | python3 "$SCRIPT_DIR/cost-values.py" field "$2" "$3"
}
is_number() { python3 "$SCRIPT_DIR/cost-values.py" number "$1"; }
within_tolerance() {
  python3 "$SCRIPT_DIR/cost-values.py" within "$1" "$2" 0.00003
}

# --- 1. the label in Kubernetes ---------------------------------------------------------
template_team=$(kubectl -n outpost get deploy archive -o jsonpath='{.spec.template.metadata.labels.team}' 2>/dev/null)
[ "$template_team" = "operations" ] \
  || fail "the pod template of outpost/archive has team='${template_team}', expected 'operations'. A label on the Deployment metadata does not reach the pods. Set it under spec.template.metadata.labels"
kubectl -n outpost rollout status deploy/archive --timeout=120s >/dev/null 2>&1 \
  || fail "the Deployment outpost/archive did not finish its rollout"
pod=$(kubectl -n outpost get pods -l app=archive -o jsonpath='{range .items[*]}{.metadata.name}{";"}{.metadata.deletionTimestamp}{";"}{.metadata.labels.team}{";"}{.metadata.creationTimestamp}{"\n"}{end}' 2>/dev/null | awk -F';' '$2 == "" { print; exit }')
[ -n "$pod" ] || fail "no running archive pod in the namespace outpost"
pod_name=$(echo "$pod" | cut -d';' -f1)
pod_team=$(echo "$pod" | cut -d';' -f3)
pod_created=$(echo "$pod" | cut -d';' -f4)
[ "$pod_team" = "operations" ] || fail "the pod ${pod_name} has team='${pod_team}'. The pod must carry team=operations"
echo "OK: the pod ${pod_name} carries team=operations"

# --- 2. the label in the OpenCost API -----------------------------------------------------
created_epoch=$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$pod_created" +%s 2>/dev/null || date -u -d "$pod_created" +%s 2>/dev/null)
[ -n "$created_epoch" ] || fail "could not read the start time of the pod ${pod_name}"
seen=""
for _ in $(seq 1 24); do
  now=$(date +%s)
  result=$(kubectl get --raw "${API}?window=${created_epoch},${now}&aggregate=pod,label:team&filter=namespace:%22outpost%22" 2>/dev/null || true)
  if printf '%s' "$result" | grep -q "\"${pod_name}/operations\""; then seen=yes; break; fi
  if printf '%s' "$result" | grep -q "\"${pod_name}/__unallocated__\""; then seen=unallocated; fi
  sleep 20
done
[ "$seen" = "yes" ] \
  || fail "OpenCost does not list the pod ${pod_name} under the team operations (state: '${seen:-not listed}'). Wait about five minutes after the pod starts, then submit again"
echo "OK: OpenCost lists ${pod_name} under the team operations"

# --- 3. the report ----------------------------------------------------------------------------
kubectl -n default get configmap team-cost-report >/dev/null 2>&1 \
  || fail "the ConfigMap team-cost-report does not exist in the namespace default"
report() { kubectl -n default get configmap team-cost-report -o jsonpath="{.data.$1}" 2>/dev/null; }
window=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}' 2>/dev/null)
[ -n "$window" ] || fail "the ConfigMap report-window is missing. Do not delete it"
used_window=$(report window)
[ "$used_window" = "$window" ] || fail "the key window is '${used_window}', expected '${window}'"
echo "OK: the report names the window ${window}"
result=$(kubectl get --raw "${API}?window=${window}&aggregate=label:team&filter=namespace:%22starfleet%22,%22outpost%22" 2>/dev/null)
[ -n "$result" ] || fail "OpenCost did not answer. Check the pod in the namespace opencost"
for pair in navigation:navigation research:research unallocated:__unallocated__; do
  key=${pair%%:*}
  bucket=${pair##*:}
  expected=$(field_of "$result" "$bucket" totalCost)
  [ -n "$expected" ] || fail "OpenCost returned no cost for ${bucket} in the window ${window}"
  reported=$(report "$key")
  [ -n "$reported" ] || fail "the key ${key} is missing from the ConfigMap team-cost-report"
  is_number "$reported" || fail "the key ${key} is '${reported}'. Store only the number from the field totalCost"
  within_tolerance "$reported" "$expected" \
    || fail "the cost for ${key} is ${reported}, but OpenCost returns ${expected} for the window ${window}. Use aggregate=label:team and the field totalCost"
  echo "OK: ${key} cost ${reported} (OpenCost: ${expected})"
done

# --- 4. nothing else was changed ----------------------------------------------------------
archive_cpu=$(kubectl -n outpost get deploy archive -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
[ "$archive_cpu" = "300m" ] || fail "the CPU request of archive changed to '${archive_cpu}'. Attribute the cost, do not change the requests"
scout_team=$(kubectl -n starfleet get deploy scout -o jsonpath='{.spec.template.metadata.labels.team}' 2>/dev/null)
[ "$scout_team" = "navigation" ] || fail "the team label of scout changed to '${scout_team}'"
echo "OK: the other workloads are unchanged"

echo "PASS: archive is attributed to operations and the team costs match OpenCost"
exit 0
