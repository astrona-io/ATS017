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
# Verify both protocol permissions to the combined DNS peer in allow-dns.
selector=$(kubectl -n starfleet get networkpolicy allow-dns -o go-template='{{if not .spec.podSelector}}all{{end}}')
[ "$selector" = all ] || fail "allow-dns must select every tenant Pod"
dns_ports=$(kubectl -n starfleet get networkpolicy allow-dns -o go-template='{{range .spec.egress}}{{$rule := .}}{{range .to}}{{if .namespaceSelector}}{{if .podSelector}}{{if eq (index .namespaceSelector.matchLabels "kubernetes.io/metadata.name") "kube-system"}}{{if eq (index .podSelector.matchLabels "k8s-app") "kube-dns"}}{{range $rule.ports}}{{.protocol}}:{{.port}} {{end}}{{end}}{{end}}{{end}}{{end}}{{end}}{{end}}')
case "$dns_ports" in *UDP:53*) ;; *) fail "allow-dns needs UDP 53 to the combined CoreDNS peer" ;; esac
case "$dns_ports" in *TCP:53*) ;; *) fail "allow-dns needs TCP 53 to the combined CoreDNS peer" ;; esac
# curl's verbose connect attempt proves resolution even when HTTP egress is denied.
service_address=$(kubectl -n starfleet get service probe -o jsonpath='{.spec.clusterIP}')
[ -n "$service_address" ] || fail "probe Service has no ClusterIP"
for workload in shuttle probe drifter; do
  trace=$(kubectl -n starfleet exec "deploy/$workload" -c client -- curl --noproxy '*' --verbose --connect-timeout 2 --max-time 3 http://probe.starfleet.svc.cluster.local/get 2>&1) || true
  printf '%s\n' "$trace" | grep -Fq "Trying $service_address:80" || fail "DNS must resolve probe from starfleet/$workload"
done
echo "PASS: dns"
