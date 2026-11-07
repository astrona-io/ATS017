#!/usr/bin/env bash
# Grading for ats-017-lab-040-02-03, part 2. Checks:
#   1. the Deployment starfleet/relay (the most expensive one) runs exactly
#      one replica, and starfleet/beacon (the least expensive one) runs
#      exactly three; both rollouts finished and every replica is ready
#   2. the requests of relay and beacon are unchanged (the task is to change
#      the replica count, not the request), and shuttle gets HTTP 200 from
#      both Services
#   3. scout and shuttle still run one replica each
set -u

fail() { echo "FAIL: $*"; exit 1; }

# replicas_of <deployment>: spec.replicas, or 1 when the field is not set.
replicas_of() {
  local replicas
  replicas=$(kubectl -n starfleet get deploy "$1" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  echo "${replicas:-1}"
}
# ready_of <deployment>: status.readyReplicas, or 0 when the field is not set.
ready_of() {
  local ready
  ready=$(kubectl -n starfleet get deploy "$1" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  echo "${ready:-0}"
}
# requests_of <deployment>: "<cpu> <memory>" of the first container.
requests_of() {
  kubectl -n starfleet get deploy "$1" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu} {.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null
}
# answers <service>: shuttle gets HTTP 200 from the Service within 30 seconds.
answers() {
  local status=000
  for _ in $(seq 1 15); do
    status=$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://$1" 2>/dev/null || true)
    [ "$status" = "200" ] && return 0
    sleep 2
  done
  fail "shuttle gets HTTP ${status} from the Service $1, expected 200"
}

# --- 1. the replica counts ---------------------------------------------------------------
for name in relay beacon scout shuttle; do
  kubectl -n starfleet get deploy "$name" >/dev/null 2>&1 \
    || fail "the Deployment ${name} does not exist in the namespace starfleet. Scale the Deployments, do not delete them"
done
[ "$(replicas_of relay)" = "1" ] \
  || fail "relay runs $(replicas_of relay) replicas. It is the most expensive Deployment, so scale it down to 1"
[ "$(replicas_of beacon)" = "3" ] \
  || fail "beacon runs $(replicas_of beacon) replicas. It is the least expensive Deployment, so scale it up to 3"
kubectl -n starfleet rollout status deploy/relay --timeout=120s >/dev/null 2>&1 \
  || fail "the Deployment relay did not finish its rollout"
kubectl -n starfleet rollout status deploy/beacon --timeout=120s >/dev/null 2>&1 \
  || fail "the Deployment beacon did not finish its rollout"
[ "$(ready_of relay)" = "1" ] || fail "relay has $(ready_of relay) ready replicas, expected 1"
[ "$(ready_of beacon)" = "3" ] || fail "beacon has $(ready_of beacon) ready replicas, expected 3"
echo "OK: relay runs 1 replica and beacon runs 3, all ready"

# --- 2. the requests are unchanged and both Services answer --------------------------------
[ "$(requests_of relay)" = "400m 256Mi" ] \
  || fail "the requests of relay changed to '$(requests_of relay)'. Change the replica count, keep the requests at 400m and 256Mi"
[ "$(requests_of beacon)" = "25m 32Mi" ] \
  || fail "the requests of beacon changed to '$(requests_of beacon)'. Change the replica count, keep the requests at 25m and 32Mi"
answers relay
answers beacon
echo "OK: the requests are unchanged and shuttle gets 200 from relay and beacon"

# --- 3. nothing else was scaled ------------------------------------------------------------
[ "$(replicas_of scout)" = "1" ] \
  || fail "scout runs $(replicas_of scout) replicas. Scale only the most and the least expensive Deployment"
[ "$(replicas_of shuttle)" = "1" ] \
  || fail "shuttle runs $(replicas_of shuttle) replicas. Scale only the most and the least expensive Deployment"
echo "OK: scout and shuttle still run one replica each"

echo "PASS: the replica counts follow the cost ranking"
exit 0
