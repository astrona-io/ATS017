#!/usr/bin/env bash
set -euo pipefail
NAMESPACE=pipeline-scout
CLAIM_CAP=2
STORAGE_CAP=4Gi
CHECK_NAME=planned-limits-1
source "$(dirname "$0")/bounded-storage-checks.sh"
