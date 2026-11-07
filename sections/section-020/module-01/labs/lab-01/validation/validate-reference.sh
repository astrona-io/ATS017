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
route_ready relay || fail "relay needs current Accepted=True and ResolvedRefs=True on listener http"
backend=$(kubectl -n outpost get httproute relay -o jsonpath='{range .spec.rules[*].backendRefs[*]}{.namespace}/{.name}:{.port}{"\n"}{end}')
[ "$backend" = "starfleet/bridge:80" ] || fail "relay must reference starfleet/bridge on Service port 80"
body=$(request relay.starfleet.example /) || fail "relay request failed; check the ReferenceGrant in starfleet"
[ "$body" = "starfleet front end" ] || fail "relay must reach starfleet/bridge through the Gateway"
# Without a permitting ReferenceGrant the controller cannot resolve this cross-namespace reference.
[ -n "$(kubectl -n starfleet get referencegrants -o name)" ] || fail "create a ReferenceGrant in starfleet"
echo "PASS: reference"
