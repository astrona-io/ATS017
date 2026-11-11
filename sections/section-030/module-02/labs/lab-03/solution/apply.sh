#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl -n starfleet set resources deployment/scout-underprovisioned --requests=cpu=20m,memory=160Mi --limits=memory=160Mi
kubectl -n starfleet rollout status deployment/scout-underprovisioned --timeout=180s
