#!/usr/bin/env bash
set -euo pipefail
NAMESPACE=pipeline-probe
CLAIM_CAP=3
STORAGE_CAP=6Gi
CHECK_NAME=planned-limits-2
source "$(dirname "$0")/bounded-storage-checks.sh"
