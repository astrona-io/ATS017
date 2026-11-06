#!/usr/bin/env bash
# Live tests use direct Pod addresses; a DNS or kubectl error cannot pass a deny.
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
pod_ip() {
  local namespace="$1" workload="$2" ready address
  ready=$(kubectl -n "$namespace" get pods -l "app=$workload" -o jsonpath='{range .items[*]}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\n"}{end}')
  [ "$ready" = True ] || fail "$namespace/$workload must have exactly one Ready Pod"
  address=$(kubectl -n "$namespace" get pods -l "app=$workload" -o jsonpath='{.items[0].status.podIP}')
  [ -n "$address" ] || fail "$namespace/$workload has no Pod IP"
  printf '%s' "$address"
}
request() {
  local namespace="$1" workload="$2" url="$3"
  kubectl -n "$namespace" exec "deploy/$workload" -c client -- \
    curl --noproxy '*' --fail --silent --show-error --connect-timeout 2 --max-time 3 "$url"
}
allowed() {
  request "$@" >/dev/null || fail "allowed connection failed: $*"
}
denied() {
  local result=0
  request "$@" >/dev/null 2>&1 || result=$?
  [ "$result" -eq 28 ] || fail "expected policy timeout (28), got $result: $*"
}
isolated() {
  local baseline
  baseline=$(kubectl -n starfleet get networkpolicy default-deny -o go-template='{{if not .spec.podSelector}}{{if not .spec.ingress}}{{if not .spec.egress}}{{range .spec.policyTypes}}{{.}} {{end}}{{end}}{{end}}{{end}}') || fail "create default-deny"
  case "$baseline" in *Ingress*) ;; *) fail "default-deny must select all Pods with empty ingress" ;; esac
  case "$baseline" in *Egress*) ;; *) fail "default-deny must select all Pods with empty egress" ;; esac
}
# Pair negative tests with healthy listeners, so stopping a server cannot pass.
healthy_targets() {
  local workload
  for workload in shuttle probe drifter; do
    pod_ip starfleet "$workload" >/dev/null
    allowed starfleet "$workload" http://127.0.0.1:9898/metrics
  done
  allowed starfleet probe http://127.0.0.1:8080/get
  pod_ip outpost shuttle >/dev/null
  allowed outpost shuttle http://127.0.0.1:9898/metrics
  pod_ip outpost drifter >/dev/null
  pod_ip relay shuttle >/dev/null
}
isolated
healthy_targets
namespace_label=$(kubectl get namespace outpost -o jsonpath='{.metadata.labels.purpose}')
[ "$namespace_label" = monitoring ] || fail "keep purpose=monitoring on outpost"
for workload in shuttle probe drifter; do
  tenant_address=$(pod_ip starfleet "$workload")
  allowed outpost shuttle "http://$tenant_address:9898/metrics"
  denied outpost drifter "http://$tenant_address:9898/metrics"
  denied relay shuttle "http://$tenant_address:9898/metrics"
  if [ "$workload" != shuttle ]; then
    denied starfleet shuttle "http://$tenant_address:9898/metrics"
  fi
done
backend_address=$(pod_ip starfleet probe)
denied outpost shuttle "http://$backend_address:8080/get"
echo "PASS: monitoring"
