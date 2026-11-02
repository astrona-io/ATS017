#!/usr/bin/env bash
# Grading for ats-017-capstone-040. Checks:
#   1. every Deployment carries the right team label on its pod template:
#      scout and shuttle navigation, probe and archive operations,
#      analytics science
#   2. the ConfigMap default/cost-report names the stored window and the cost
#      of each team for it, each within 15 percent (at least 0.00003 dollars,
#      because OpenCost rounds to 5 decimals) of the sum of the Deployments the
#      team owns, as OpenCost returns them for that closed window
#   3. the key least-efficient names the Deployment with the lowest
#      totalEfficiency in that window
#   4. that Deployment (analytics) now requests a fitting amount of CPU and
#      memory, still runs and still answers shuttle with HTTP 200
#   5. the requests of the other workloads were not changed to fake a result
set -u

API="/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute"
fail() { echo "FAIL: $*"; exit 1; }

field_of() {
  printf '%s' "$1" | sed -n "s|.*\"$2\":{\"name\":\"$2\",||p" | grep -o "\"$3\":[-0-9.e]*" | head -1 | cut -d: -f2
}
is_number() { awk -v value="$1" 'BEGIN { exit !(value ~ /^[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$/) }'; }
within_tolerance() {
  awk -v reported="$1" -v expected="$2" 'BEGIN {
    allowed = expected * 0.15; if (allowed < 0.00003) allowed = 0.00003
    diff = reported - expected; if (diff < 0) diff = -diff
    exit !(diff <= allowed)
  }'
}
to_millicores() {
  case "$1" in
    *m) echo "${1%m}" ;;
    *) awk -v value="$1" 'BEGIN { printf "%d", value * 1000 }' ;;
  esac
}
to_mebibytes() {
  case "$1" in
    *Ki) awk -v value="${1%Ki}" 'BEGIN { printf "%d", value / 1024 }' ;;
    *Mi) echo "${1%Mi}" ;;
    *Gi) awk -v value="${1%Gi}" 'BEGIN { printf "%d", value * 1024 }' ;;
    *M) awk -v value="${1%M}" 'BEGIN { printf "%d", value * 1000000 / 1048576 }' ;;
    *G) awk -v value="${1%G}" 'BEGIN { printf "%d", value * 1000000000 / 1048576 }' ;;
    *) awk -v value="$1" 'BEGIN { printf "%d", value / 1048576 }' ;;
  esac
}
in_range() { awk -v value="$1" -v low="$2" -v high="$3" 'BEGIN { exit !(value + 0 >= low + 0 && value + 0 <= high + 0) }'; }

# --- 1. the labels ------------------------------------------------------------------------
for entry in starfleet:scout:navigation starfleet:shuttle:navigation starfleet:probe:operations starfleet:analytics:science outpost:archive:operations; do
  namespace=${entry%%:*}; rest=${entry#*:}; name=${rest%%:*}; team=${rest##*:}
  actual=$(kubectl -n "$namespace" get deploy "$name" -o jsonpath='{.spec.template.metadata.labels.team}' 2>/dev/null)
  [ "$actual" = "$team" ] \
    || fail "the pod template of ${namespace}/${name} has team='${actual}', expected '${team}'. Set it under spec.template.metadata.labels"
  kubectl -n "$namespace" rollout status "deploy/${name}" --timeout=120s >/dev/null 2>&1 \
    || fail "the Deployment ${namespace}/${name} did not finish its rollout"
  pod_team=$(kubectl -n "$namespace" get pods -l "app=${name}" -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}{";"}{.metadata.labels.team}{"\n"}{end}' 2>/dev/null | awk -F';' '$1 == "" { print $2; exit }')
  [ "$pod_team" = "$team" ] || fail "the running pod of ${namespace}/${name} has team='${pod_team}', expected '${team}'"
done
echo "OK: every Deployment and pod carries its team label"

# --- 2. the report ------------------------------------------------------------------------
kubectl -n default get configmap cost-report >/dev/null 2>&1 \
  || fail "the ConfigMap cost-report does not exist in the namespace default"
report() { kubectl -n default get configmap cost-report -o jsonpath="{.data.$1}" 2>/dev/null; }
window=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}' 2>/dev/null)
[ -n "$window" ] || fail "the ConfigMap report-window is missing. Do not delete it"
[ "$(report window)" = "$window" ] || fail "the key window is '$(report window)', expected '${window}'"
echo "OK: the report names the window ${window}"
result=$(kubectl get --raw "${API}?window=${window}&aggregate=namespace,controller&filter=namespace:%22starfleet%22,%22outpost%22" 2>/dev/null)
[ -n "$result" ] || fail "OpenCost did not answer. Check the pod in the namespace opencost"
cost_of() { field_of "$result" "$1" totalCost; }
sum_of() { awk -v a="$(cost_of "$1")" -v b="${2:+$(cost_of "$2")}" 'BEGIN { printf "%.8f", a + b }'; }
for team in navigation operations science; do
  case "$team" in
    navigation) expected=$(sum_of starfleet/deployment:scout starfleet/deployment:shuttle) ;;
    operations) expected=$(sum_of starfleet/deployment:probe outpost/deployment:archive) ;;
    science)    expected=$(sum_of starfleet/deployment:analytics) ;;
  esac
  reported=$(report "$team")
  [ -n "$reported" ] || fail "the key ${team} is missing from the ConfigMap cost-report"
  is_number "$reported" || fail "the key ${team} is '${reported}'. Store only a number, in dollars"
  within_tolerance "$reported" "$expected" \
    || fail "the cost for ${team} is ${reported}, but the Deployments of that team cost ${expected} in the window ${window}. Add the totalCost of each of its Deployments"
  echo "OK: ${team} cost ${reported} (OpenCost: ${expected})"
done

# --- 3. the least efficient workload ---------------------------------------------------------
lowest=""; lowest_name=""
for controller in starfleet/deployment:scout starfleet/deployment:probe starfleet/deployment:analytics starfleet/deployment:shuttle outpost/deployment:archive; do
  efficiency=$(field_of "$result" "$controller" totalEfficiency)
  [ -n "$efficiency" ] || continue
  if [ -z "$lowest" ] || awk -v a="$efficiency" -v b="$lowest" 'BEGIN { exit !(a + 0 < b + 0) }'; then
    lowest=$efficiency; lowest_name=${controller##*:}
  fi
done
[ -n "$lowest_name" ] || fail "OpenCost returned no efficiency for the window ${window}"
[ "$(report least-efficient)" = "$lowest_name" ] \
  || fail "the key least-efficient is '$(report least-efficient)'. Compare totalEfficiency in the window ${window}; the lowest value is the Deployment to name"
echo "OK: the least efficient Deployment is ${lowest_name}"

# --- 4. the right-sizing --------------------------------------------------------------------
cpu=$(kubectl -n starfleet get deploy analytics -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
memory=$(kubectl -n starfleet get deploy analytics -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
[ -n "$cpu" ] && [ -n "$memory" ] || fail "analytics has no CPU or memory request. Set both"
in_range "$(to_millicores "$cpu")" 10 250 || fail "analytics requests ${cpu} CPU. It uses about 2m, so request between 10m and 250m"
in_range "$(to_mebibytes "$memory")" 40 384 || fail "analytics requests ${memory} memory. It uses about 25Mi, so request between 40Mi and 384Mi"
kubectl -n starfleet rollout status deploy/analytics --timeout=120s >/dev/null 2>&1 || fail "the Deployment analytics did not finish its rollout"
status=000
for _ in $(seq 1 15); do
  status=$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://analytics 2>/dev/null || true)
  [ "$status" = "200" ] && break
  sleep 2
done
[ "$status" = "200" ] || fail "shuttle gets HTTP ${status} from the Service analytics, expected 200"
echo "OK: analytics requests ${cpu} CPU and ${memory} memory and shuttle gets 200"

# --- 5. nothing else was changed ----------------------------------------------------------
scout_cpu=$(kubectl -n starfleet get deploy scout -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
probe_cpu=$(kubectl -n starfleet get deploy probe -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
archive_cpu=$(kubectl -n outpost get deploy archive -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
{ [ "$scout_cpu" = "100m" ] && [ "$probe_cpu" = "50m" ] && [ "$archive_cpu" = "50m" ]; } \
  || fail "the CPU requests of scout, probe or archive changed (${scout_cpu}, ${probe_cpu}, ${archive_cpu}). Right-size only the least efficient Deployment"
echo "OK: the other workloads are unchanged"

echo "PASS: every workload has a team, the team costs match OpenCost and analytics is right-sized"
exit 0
