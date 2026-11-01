#!/usr/bin/env bash
# Grading for ats-017-lab-030-02-01. Checks:
#   1. scout-overprovisioned: CPU request 10m to 200m, memory request 20Mi to 256Mi,
#      memory limit at least the request and at most 512Mi
#   2. scout-underprovisioned: memory request at least what the container uses and at
#      most three times that, memory limit at least the request
#   3. the process arguments and images are unchanged
#   4. both pods are Ready, and the container of scout-underprovisioned is not
#      restarted (OOMKilled) while the grader watches
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

to_millicores() {
  case "$1" in
    *m) echo "${1%m}" ;;
    "") echo 0 ;;
    *[!0-9]*) echo 0 ;;
    *) echo $(( $1 * 1000 )) ;;
  esac
}
to_mebibytes() {
  case "$1" in
    *Gi) echo $(( ${1%Gi} * 1024 )) ;;
    *Mi) echo "${1%Mi}" ;;
    *Ki) echo $(( ${1%Ki} / 1024 )) ;;
    "") echo 0 ;;
    *[!0-9]*) echo 0 ;;
    *) echo $(( $1 / 1048576 )) ;;
  esac
}
field() { kubectl -n "$NS" get deploy "$1" -o jsonpath="{.spec.template.spec.containers[0].resources.$2}" 2>/dev/null; }

for name in scout-overprovisioned scout-underprovisioned; do
  kubectl -n "$NS" get deploy "$name" >/dev/null 2>&1 || fail "the Deployment $name does not exist"
  kubectl -n "$NS" rollout status "deploy/$name" --timeout=180s >/dev/null 2>&1 || fail "the rollout of $name did not finish"
done

# --- 1. scout-overprovisioned -------------------------------------------------------
cpu_m=$(to_millicores "$(field scout-overprovisioned requests.cpu)")
mem_request=$(to_mebibytes "$(field scout-overprovisioned requests.memory)")
mem_limit=$(to_mebibytes "$(field scout-overprovisioned limits.memory)")
[ "$cpu_m" -ge 10 ] || fail "scout-overprovisioned has a CPU request of ${cpu_m}m, expected at least 10m (it must still cover what it uses)"
[ "$cpu_m" -le 200 ] || fail "scout-overprovisioned still requests ${cpu_m}m CPU. It uses about 1m, so ask for at most 200m"
[ "$mem_request" -ge 20 ] || fail "scout-overprovisioned has a memory request of ${mem_request}Mi, expected at least 20Mi (it uses about 15Mi)"
[ "$mem_request" -le 256 ] || fail "scout-overprovisioned still requests ${mem_request}Mi of memory. It uses about 15Mi, so ask for at most 256Mi"
[ "$mem_limit" -ge "$mem_request" ] || fail "scout-overprovisioned has a memory limit of ${mem_limit}Mi, below its request of ${mem_request}Mi"
[ "$mem_limit" -le 512 ] || fail "scout-overprovisioned has a memory limit of ${mem_limit}Mi, expected at most 512Mi"
echo "OK: scout-overprovisioned requests ${cpu_m}m CPU and ${mem_request}Mi memory, limit ${mem_limit}Mi"

# --- 2. scout-underprovisioned ------------------------------------------------------
under_request=$(to_mebibytes "$(field scout-underprovisioned requests.memory)")
under_limit=$(to_mebibytes "$(field scout-underprovisioned limits.memory)")
[ "$under_limit" -gt 0 ] || fail "scout-underprovisioned has no memory limit. Keep a limit that fits the usage"
[ "$under_limit" -ge "$under_request" ] || fail "scout-underprovisioned has a memory limit of ${under_limit}Mi, below its request of ${under_request}Mi"

# The container holds about 110Mi. Read the real usage when metrics-server has it,
# and fall back to 110Mi.
usage=0
for _ in $(seq 1 30); do
  top=$(kubectl -n "$NS" top pod -l app=scout-underprovisioned --no-headers 2>/dev/null | awk '{print $3}')
  usage=$(to_mebibytes "$top")
  [ "$usage" -gt 0 ] && break
  sleep 5
done
[ "$usage" -gt 0 ] || usage=110
[ "$usage" -ge 100 ] || usage=100
[ "$under_request" -ge "$usage" ] || fail "scout-underprovisioned requests ${under_request}Mi of memory but uses about ${usage}Mi. Request at least what it uses"
[ "$under_request" -le $(( usage * 3 )) ] || fail "scout-underprovisioned requests ${under_request}Mi of memory but uses about ${usage}Mi. Ask for at most three times that"
[ "$under_limit" -ge "$usage" ] || fail "scout-underprovisioned has a memory limit of ${under_limit}Mi, below its usage of about ${usage}Mi. The container is killed above its limit"
echo "OK: scout-underprovisioned requests ${under_request}Mi of memory (usage about ${usage}Mi), limit ${under_limit}Mi"

# --- 3. nothing else was changed ----------------------------------------------------
args=$(kubectl -n "$NS" get deploy scout-underprovisioned -o jsonpath='{.spec.template.spec.containers[0].args}')
case "$args" in *--stress-memory=100*) ;; *) fail "the arguments of scout-underprovisioned changed. Fix the resources, not the application" ;; esac
for name in scout-overprovisioned scout-underprovisioned; do
  image=$(kubectl -n "$NS" get deploy "$name" -o jsonpath='{.spec.template.spec.containers[0].image}')
  [ "$image" = "ghcr.io/stefanprodan/podinfo:6.15.0" ] || fail "the image of $name changed to ${image}"
done
echo "OK: arguments and images are unchanged"

# --- 4. behaviour: Ready and no OOMKilled -------------------------------------------
for name in scout-overprovisioned scout-underprovisioned; do
  ready=""
  for _ in $(seq 1 40); do
    ready=$(kubectl -n "$NS" get pods -l "app=$name" -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
    [ "$ready" = "true" ] && break
    sleep 3
  done
  [ "$ready" = "true" ] || fail "the pod of $name is not Ready"
done
restarts_before=$(kubectl -n "$NS" get pods -l app=scout-underprovisioned -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')
echo "Watching scout-underprovisioned for 30 seconds."
sleep 30
restarts_after=$(kubectl -n "$NS" get pods -l app=scout-underprovisioned -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')
ready=$(kubectl -n "$NS" get pods -l app=scout-underprovisioned -o jsonpath='{.items[0].status.containerStatuses[0].ready}')
[ "$restarts_after" = "$restarts_before" ] || fail "scout-underprovisioned restarted again (restartCount ${restarts_before} to ${restarts_after}). Check kubectl describe pod for OOMKilled"
[ "$ready" = "true" ] || fail "scout-underprovisioned is not Ready"
echo "OK: both pods are Ready and scout-underprovisioned is not restarted"

echo "PASS: both scouts request what they use, with headroom"
exit 0
