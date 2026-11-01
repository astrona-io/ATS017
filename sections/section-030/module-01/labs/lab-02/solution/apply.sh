#!/usr/bin/env bash
# Reference solution for ats-017-lab-030-01-02. Applied only by `astrona test`.
set -euo pipefail

kubectl -n starfleet patch hpa scout --type merge -p '{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds":120,"policies":[{"type":"Pods","value":1,"periodSeconds":30}]}}}}'
