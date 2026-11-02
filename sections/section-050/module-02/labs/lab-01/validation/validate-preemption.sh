#!/usr/bin/env bash
# Grading for ats-017-lab-050-02-01. Checks:
#   1. the probe Deployment is unchanged (3 replicas, same CPU request, no class)
#   2. scout-critical keeps its 300m request and uses a tenant PriorityClass
#      (value above 0, below the system range, preemption allowed)
#   3. the scout-critical pod is Ready
#   4. the scheduler preempted a probe pod (a Preempted event exists)
set -u

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. probe unchanged -----------------------------------------------------------------
expected=$(kubectl -n outpost get deploy probe -o jsonpath='{.metadata.annotations.lab/probe-cpu}' 2>/dev/null)
[ -n "$expected" ] || fail "the probe Deployment in outpost is missing. Do not delete it"
[ "$(kubectl -n outpost get deploy probe -o jsonpath='{.spec.replicas}')" = "3" ] || fail "probe must keep 3 replicas. Do not scale it down"
[ "$(kubectl -n outpost get deploy probe -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')" = "$expected" ] || fail "the CPU request of probe was changed. Leave probe as it is"
[ -z "$(kubectl -n outpost get deploy probe -o jsonpath='{.spec.template.spec.priorityClassName}')" ] || fail "do not change the PriorityClass of probe. Give priority to scout-critical"
echo "OK: probe is unchanged"

# --- 2. scout-critical and its class ----------------------------------------------------
[ "$(kubectl -n starfleet get deploy scout-critical -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')" = "300m" ] || fail "scout-critical must keep its 300m CPU request. Do not shrink it to fit"
class=$(kubectl -n starfleet get deploy scout-critical -o jsonpath='{.spec.template.spec.priorityClassName}')
[ -n "$class" ] || fail "scout-critical has no priorityClassName"
case "$class" in
  system-*) fail "do not use a system PriorityClass (${class}). Create a class for the tenant" ;;
esac
value=$(kubectl get priorityclass "$class" -o jsonpath='{.value}' 2>/dev/null)
[ -n "$value" ] || fail "the PriorityClass ${class} does not exist"
[ "$value" -gt 0 ] && [ "$value" -lt 1000000000 ] || fail "the PriorityClass ${class} has value ${value}. Use a value above 0 and below 1000000000"
policy=$(kubectl get priorityclass "$class" -o jsonpath='{.preemptionPolicy}')
[ "$policy" = "Never" ] && fail "the class ${class} has preemptionPolicy Never, so it cannot evict pods"
echo "OK: scout-critical uses the PriorityClass ${class} (value ${value})"

# --- 3. the pod is Ready -----------------------------------------------------------------
ready=0
for _ in $(seq 1 60); do
  ready=$(kubectl -n starfleet get pods -l app=scout-critical -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}|{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c '^|true$')
  [ "$ready" = "1" ] && break
  sleep 3
done
[ "$ready" = "1" ] || fail "the scout-critical pod is not Ready after 3 minutes"
echo "OK: the scout-critical pod is Ready"

# --- 4. a probe pod was preempted --------------------------------------------------------
preempted=0
for _ in $(seq 1 20); do
  preempted=$(kubectl get events -A --field-selector reason=Preempted -o name 2>/dev/null | wc -l | tr -d ' ')
  [ "$preempted" -ge 1 ] && break
  sleep 3
done
[ "$preempted" -ge 1 ] || fail "no Preempted event exists. The pod must run because the scheduler preempted a lower-priority pod"
echo "OK: the scheduler preempted a probe pod"

echo "PASS: scout-critical runs through a PriorityClass and preemption"
exit 0
