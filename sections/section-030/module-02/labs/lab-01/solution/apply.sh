#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl -n starfleet set resources deployment/scout-overprovisioned --requests=cpu=20m,memory=64Mi --limits=memory=128Mi
kubectl -n starfleet rollout status deployment/scout-overprovisioned --timeout=180s
