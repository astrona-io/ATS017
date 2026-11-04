#!/usr/bin/env bash
# Shared API paths. astrona supplies the active lab KUBECONFIG.
set -euo pipefail
OPENCOST_API=/api/v1/namespaces/opencost/services/opencost:9003/proxy
PROMETHEUS_API=/api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1
RESULT_DIR=/tmp/cnpe-cost-review
fail() { echo "FAIL: $*" >&2; exit 1; }
