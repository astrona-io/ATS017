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
request() {
  local hostname="$1" path="$2"
  shift 2
  kubectl -n starfleet exec deploy/shuttle -- curl --fail --silent --show-error --max-time 8 \
    -H "Host: $hostname" "$@" "http://$gateway_address$path"
}
gateway_controller=$(kubectl get gatewayclass eg -o jsonpath='{.spec.controllerName}')
[ -n "$gateway_controller" ] || fail "GatewayClass eg has no controller"
gateway_address=$(kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{.status.addresses[0].value}')
[ -n "$gateway_address" ] || fail "Gateway has no address"
listener=$(kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{range .spec.listeners[?(@.name=="http")]}{.protocol}:{.port}{end}')
[ "$listener" = HTTP:80 ] || fail "keep listener http on HTTP port 80"
route_ready team-route || fail "team-route needs current Accepted=True and ResolvedRefs=True on listener http"
rules=$(kubectl -n outpost get httproute team-route -o go-template='{{range .spec.rules}}{{$rule := .}}{{range .matches}}{{if .path}}{{.path.type}}:{{.path.value}}{{end}}{{range .headers}} header={{.name}}:{{if .type}}{{.type}}{{else}}Exact{{end}}:{{.value}}{{end}}{{range $rule.backendRefs}} backend={{if .namespace}}{{.namespace}}{{else}}outpost{{end}}/{{.name}}:{{.port}}{{end}}{{"\n"}}{{end}}{{end}}')
printf '%s\n' "$rules" | grep -Fqx 'PathPrefix:/api backend=outpost/scout:80' || fail "add PathPrefix /api to outpost/scout on port 80"
body=$(request team.starfleet.example /api/info "$@") || fail "/api/info request failed"
scout_pods=$(kubectl -n outpost get pods -l app=scout -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
matched=false
while IFS= read -r pod; do
  [ -n "$pod" ] || continue
  if printf '%s' "$body" | grep -Eq '"hostname"[[:space:]]*:[[:space:]]*"'"$pod"'"'; then matched=true; fi
done <<< "$scout_pods"
[ "$matched" = true ] || fail "/api/info must return a live outpost/scout pod hostname"
echo "PASS: path"
