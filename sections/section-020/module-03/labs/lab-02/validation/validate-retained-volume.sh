#!/usr/bin/env bash
# Grading for ats-017-lab-020-03-02. Checks:
#   1. probe-data is still Bound and probe-storage still reads its file
#   2. the volume behind probe-data has the Retain policy
#   3. exactly one default class, standard-retain, and a claim without a
#      class receives it
set -u

NS="starfleet"
DEFAULT_ANNOTATION='storageclass\.kubernetes\.io/is-default-class'

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. the claim and the data are untouched -------------------------------------
phase=$(kubectl -n "$NS" get pvc probe-data -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$phase" = "Bound" ] || fail "probe-data is '${phase:-missing}', expected Bound. Do not delete or recreate the claim"
deleting=$(kubectl -n "$NS" get pvc probe-data -o jsonpath='{.metadata.deletionTimestamp}')
[ -z "$deleting" ] || fail "probe-data is being deleted"
echo "OK: probe-data is Bound"

found=$(kubectl -n "$NS" exec probe-storage -- cat /data/message.txt 2>/dev/null)
[ "$found" = "saved-by-probe" ] || fail "/data/message.txt in probe-storage is missing or changed. The data must stay in place"
echo "OK: /data/message.txt still reads saved-by-probe"

# --- 2. the volume policy ----------------------------------------------------------
volume=$(kubectl -n "$NS" get pvc probe-data -o jsonpath='{.spec.volumeName}')
policy=$(kubectl get pv "$volume" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null)
[ "$policy" = "Retain" ] || fail "volume $volume has reclaim policy '${policy:-unknown}', expected Retain"
echo "OK: volume $volume has reclaim policy Retain"

# --- 3. the default class ----------------------------------------------------------
defaults=$(kubectl get storageclass \
  -o jsonpath="{range .items[*]}{.metadata.name}{\"=\"}{.metadata.annotations.${DEFAULT_ANNOTATION}}{\"\n\"}{end}" \
  | grep '=true$' | cut -d= -f1 | tr '\n' ' ')
[ "$defaults" = "standard-retain " ] || fail "default StorageClass is '${defaults:-none}', expected only standard-retain"
echo "OK: standard-retain is the only default StorageClass"

kubectl -n "$NS" apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grader-default-check
  namespace: starfleet
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 16Mi
YAML
class=$(kubectl -n "$NS" get pvc grader-default-check -o jsonpath='{.spec.storageClassName}')
kubectl -n "$NS" delete pvc grader-default-check --wait=false >/dev/null 2>&1
[ "$class" = "standard-retain" ] || fail "a claim without storageClassName received '${class:-no class}', expected standard-retain"
echo "OK: a claim without storageClassName receives standard-retain"

echo "PASS: the volume is retained and the default class is standard-retain"
exit 0
