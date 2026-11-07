#!/usr/bin/env bash
# Read live conditions and send requests through the Gateway, never directly to a backend.
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
route_ready() {
  local route="$1" parents
  parents=$(kubectl -n outpost get httproute "$route" -o jsonpath='{range .status.parents[*]}{.parentRef.namespace}/{.parentRef.name}/{.parentRef.sectionName}{" "}{.controllerName}{" "}{range .conditions[*]}{.type}={.status}:{.observedGeneration}{" "}{end}{"\n"}{end}') || return 1
  local generation
  generation=$(kubectl -n outpost get httproute "$route" -o jsonpath='{.metadata.generation}')
  # Accept only the intended parent and fresh conditions, on the same status entry.
  while IFS= read -r parent; do
    case "$parent" in
      "starfleet/starfleet-gateway/http $gateway_controller "*)
        case "$parent" in *"Accepted=True:$generation "*) ;; *) continue ;; esac
        case "$parent" in *"ResolvedRefs=True:$generation "*) return 0 ;; esac ;;
    esac
  done <<< "$parents"
  return 1
}
# Envoy programs a route a moment after its status says Accepted, so retry a
# failed request a few times before calling it a failure.
request() {
  local hostname="$1" path="$2" attempt
  shift 2
  for attempt in $(seq 1 10); do
    if kubectl -n starfleet exec deploy/shuttle -- curl --fail --silent --show-error --max-time 8 \
      -H "Host: $hostname" "$@" "http://$gateway_address$path"; then
      return 0
    fi
    [ "$attempt" -eq 10 ] && return 1
    sleep 3
  done
}
gateway_controller=$(kubectl get gatewayclass eg -o jsonpath='{.spec.controllerName}')
[ -n "$gateway_controller" ] || fail "GatewayClass eg has no controller"
gateway_address=$(kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{.status.addresses[0].value}')
[ -n "$gateway_address" ] || fail "Gateway has no address"
listener=$(kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{range .spec.listeners[?(@.name=="http")]}{.protocol}:{.port}{end}')
[ "$listener" = HTTP:80 ] || fail "keep listener http on HTTP port 80"
route_ready team-route || fail "team-route needs current Accepted=True and ResolvedRefs=True on listener http"
rules=$(kubectl -n outpost get httproute team-route -o go-template='{{range .spec.rules}}{{$rule := .}}{{range .matches}}{{if .path}}{{.path.type}}:{{.path.value}}{{end}}{{range .headers}} header={{.name}}:{{if .type}}{{.type}}{{else}}Exact{{end}}:{{.value}}{{end}}{{range $rule.backendRefs}} backend={{if .namespace}}{{.namespace}}{{else}}outpost{{end}}/{{.name}}:{{.port}}{{end}}{{"\n"}}{{end}}{{end}}')
printf '%s\n' "$rules" | grep -Fqx 'PathPrefix:/ header=x-version:Exact:canary backend=outpost/probe:80' || fail "add exact x-version canary with PathPrefix / to outpost/probe on port 80"
body=$(request team.starfleet.example /headers -H 'x-version: canary') || fail "canary request failed"
printf '%s' "$body" | grep -Eq '"X-Version"[[:space:]]*:' || fail "probe must echo the canary header"
printf '%s' "$body" | grep -F 'canary' >/dev/null || fail "probe must echo canary"
body=$(request team.starfleet.example /) || fail "default request failed"
[ "$body" = "outpost front end" ] || fail "requests without the header must still reach bridge"
set -- -H 'x-version: canary'
body=$(request team.starfleet.example /api/info "$@") || fail "/api/info request failed"
scout_pods=$(kubectl -n outpost get pods -l app=scout -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
matched=false
while IFS= read -r pod; do
  [ -n "$pod" ] || continue
  if printf '%s' "$body" | grep -Eq '"hostname"[[:space:]]*:[[:space:]]*"'"$pod"'"'; then matched=true; fi
done <<< "$scout_pods"
[ "$matched" = true ] || fail "/api/info must return a live outpost/scout pod hostname"
echo "PASS: header"
