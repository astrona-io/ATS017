#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Keep in step with solution.md.
set -euo pipefail

# 1. Change the policy on the existing volume. The class cannot change it.
PROBE_VOLUME=$(kubectl -n starfleet get pvc probe-data -o jsonpath='{.spec.volumeName}')
kubectl patch pv "$PROBE_VOLUME" -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

# 2. Move the default mark to standard-retain.
kubectl annotate storageclass standard storageclass.kubernetes.io/is-default-class=false --overwrite
kubectl annotate storageclass standard-retain storageclass.kubernetes.io/is-default-class=true --overwrite
