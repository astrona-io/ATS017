#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
kubectl get --raw "${OPENCOST_API}/allNodePricing" | jq -e '
  .data.default | (.CPU | tonumber) == 0.045 and (.RAM | tonumber) == 0.006
' >/dev/null || fail 'pricing-active: OpenCost has not loaded the new regular rates'
kubectl get --raw "${OPENCOST_API}/allNodePricing" | jq -e '
  .data["default,spot"].CPU | tonumber == 0.009
' >/dev/null || fail 'pricing-active: OpenCost has not loaded spotCPU'
kubectl get --raw "${OPENCOST_API}/metrics" | awk '
  $1 == "kubecost_network_internet_egress_cost" && $2 + 0 == 0.09 { matched=1 }
  END { exit !matched }
' || fail 'pricing-active: the exported Internet egress rate is not 0.09'
echo 'PASS: pricing-active'
