#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
kubectl -n opencost get configmap custom-pricing-model -o json | jq -e '
  .data | .provider == "custom" and .CPU == "0.045" and .RAM == "0.006"
  and .spotCPU == "0.009" and .internetNetworkEgress == "0.09"
  and (.spotRAM | tonumber) == 0.000892 and (.GPU | tonumber) == 0.95
  and (.storage | tonumber) == 0.00005479452
  and (.zoneNetworkEgress | tonumber) == 0.01 and (.regionNetworkEgress | tonumber) == 0.01
' >/dev/null || fail 'pricing-model: set all four rates in custom-pricing-model'
echo 'PASS: pricing-model'
