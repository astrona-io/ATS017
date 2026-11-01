#!/usr/bin/env bash
# Reference solution for ats-017-lab-030-02-02. Applied only by `astrona test`.
set -euo pipefail

pod=$(kubectl -n starfleet get pods -l app=scout -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet patch pod "$pod" --subresource resize --patch \
  '{"spec":{"containers":[{"name":"scout","resources":{"requests":{"cpu":"500m"},"limits":{"cpu":"1"}}}]}}'
