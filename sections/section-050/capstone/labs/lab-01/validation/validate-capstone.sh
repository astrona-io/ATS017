#!/usr/bin/env bash
# Grading for ats-017-capstone-050. Checks:
#   1. outpost is untouched: probe unchanged, outpost-quota unchanged
#   2. PriorityClass platform-high exists (value 100000 to 999999999, preemption allowed)
#      and scout-critical uses it, keeps 300m, and is Ready after a Preempted event
#   3. batch-worker has 2 Ready pods and a LimitRange in outpost sets the defaults
#   4. a pod of class platform-high in outpost is rejected by a quota
#   5. an ordinary pod in outpost is accepted; a platform-high pod in starfleet is accepted
set -u

fail() { echo "FAIL: $*"; exit 1; }
cleanup() {
  kubectl -n outpost delete pod check-high check-plain --ignore-not-found --wait=false >/dev/null 2>&1
  kubectl -n starfleet delete pod check-high-other --ignore-not-found --wait=false >/dev/null 2>&1
}
trap cleanup EXIT

# --- 1. outpost untouched ----------------------------------------------------------------
expected=$(kubectl -n outpost get deploy probe -o jsonpath='{.metadata.annotations.lab/probe-cpu}' 2>/dev/null)
[ -n "$expected" ] || fail "the probe Deployment in outpost is missing. Do not delete it"
[ "$(kubectl -n outpost get deploy probe -o jsonpath='{.spec.replicas}')" = "3" ] || fail "probe must keep 3 replicas"
[ "$(kubectl -n outpost get deploy probe -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')" = "$expected" ] || fail "the CPU request of probe was changed. Leave probe as it is"
[ -z "$(kubectl -n outpost get deploy probe -o jsonpath='{.spec.template.spec.priorityClassName}')" ] || fail "do not change the PriorityClass of probe"
[ "$(kubectl -n outpost get resourcequota outpost-quota -o jsonpath='{.spec.hard.requests\.memory}|{.spec.hard.limits\.memory}' 2>/dev/null)" = "512Mi|1Gi" ] || fail "the quota outpost-quota must stay as it is (requests.memory 512Mi, limits.memory 1Gi). Do not delete or raise it"
echo "OK: probe and outpost-quota are unchanged"

# --- 2. preemption -----------------------------------------------------------------------
[ "$(kubectl -n starfleet get deploy scout-critical -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')" = "300m" ] || fail "scout-critical must keep its 300m CPU request"
[ "$(kubectl -n starfleet get deploy scout-critical -o jsonpath='{.spec.template.spec.priorityClassName}')" = "platform-high" ] || fail "scout-critical must use the PriorityClass platform-high"
value=$(kubectl get priorityclass platform-high -o jsonpath='{.value}' 2>/dev/null)
[ -n "$value" ] || fail "the PriorityClass platform-high does not exist"
[ "$value" -ge 100000 ] && [ "$value" -lt 1000000000 ] || fail "platform-high has value ${value}. Use a value from 100000 up to 999999999"
[ "$(kubectl get priorityclass platform-high -o jsonpath='{.preemptionPolicy}')" != "Never" ] || fail "platform-high has preemptionPolicy Never, so it cannot evict pods"

ready=0
for _ in $(seq 1 60); do
  ready=$(kubectl -n starfleet get pods -l app=scout-critical -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}|{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c '^|true$')
  [ "$ready" = "1" ] && break
  sleep 3
done
[ "$ready" = "1" ] || fail "the scout-critical pod is not Ready after 3 minutes"
preempted=0
for _ in $(seq 1 20); do
  preempted=$(kubectl get events -A --field-selector reason=Preempted -o name 2>/dev/null | wc -l | tr -d ' ')
  [ "$preempted" -ge 1 ] && break
  sleep 3
done
[ "$preempted" -ge 1 ] || fail "no Preempted event exists. The pod must run because the scheduler preempted a lower-priority pod"
echo "OK: scout-critical runs through platform-high and preemption"

# --- 3. LimitRange defaults and batch-worker --------------------------------------------
lr=$(kubectl -n outpost get limitrange -o jsonpath='{range .items[*]}{range .spec.limits[*]}{.type}|{.defaultRequest.memory}|{.default.memory}{"\n"}{end}{end}' 2>/dev/null | grep '^Container|[0-9A-Za-z]\+|[0-9A-Za-z]\+$' | head -1)
[ -n "$lr" ] || fail "no LimitRange in outpost sets a default memory request and a default memory limit for Container"
ready=0
for _ in $(seq 1 60); do
  ready=$(kubectl -n outpost get pods -l app=batch-worker -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}|{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c '^|true$')
  [ "$ready" = "2" ] && break
  sleep 3
done
[ "$ready" = "2" ] || fail "batch-worker has ${ready} Ready pod(s), expected 2. Set defaults with a LimitRange in outpost"
[ -z "$(kubectl -n outpost get deploy batch-worker -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')" ] || fail "do not add resources to the batch-worker Deployment. Use a LimitRange"
echo "OK: batch-worker runs on LimitRange defaults"

pod_yaml() { # name namespace class
  echo "apiVersion: v1
kind: Pod
metadata:
  name: $1
  namespace: $2
spec:"
  [ -n "$3" ] && echo "  priorityClassName: $3"
  echo "  containers:
    - name: probe
      image: mccutchen/go-httpbin:2.25.0
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          memory: 32Mi"
}

# --- 4. platform-high is blocked in outpost ---------------------------------------------
rejected=0
for _ in $(seq 1 30); do
  if output=$(pod_yaml check-high outpost platform-high | kubectl apply -f - 2>&1); then
    kubectl -n outpost delete pod check-high --ignore-not-found --wait=true >/dev/null 2>&1
    sleep 2
  else
    echo "$output" | grep -q "exceeded quota" && rejected=1
    break
  fi
done
[ "$rejected" = "1" ] || fail "a platform-high pod in outpost was not rejected by a quota: ${output:-accepted every time}"
echo "OK: a platform-high pod in outpost is rejected (exceeded quota)"

# --- 5. other pods are accepted ---------------------------------------------------------
output=$(pod_yaml check-plain outpost "" | kubectl apply -f - 2>&1) || fail "an ordinary pod in outpost was rejected: ${output}. The quota must count only platform-high pods"
output=$(pod_yaml check-high-other starfleet platform-high | kubectl apply -f - 2>&1) || fail "a platform-high pod in starfleet was rejected: ${output}. Create the quota only in outpost"
echo "OK: an ordinary pod in outpost and a platform-high pod in starfleet are accepted"

echo "PASS: the tenant rules hold"
exit 0
