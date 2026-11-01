#!/usr/bin/env bash
# Grading for ats-017-lab-020-03. Checks behaviour:
#   1. claim scout-data is Bound, class standard, no multi-node access mode
#   2. scout is ready and mounts scout-data (not emptyDir or hostPath) at /data
#   3. a file written to /data is still there after the scout pod is replaced
set -u

NS="starfleet"

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. the claim ---------------------------------------------------------------
phase=$(kubectl -n "$NS" get pvc scout-data -o jsonpath='{.status.phase}' 2>/dev/null)
[ -n "$phase" ] || fail "PersistentVolumeClaim scout-data not found in $NS"
[ "$phase" = "Bound" ] || fail "scout-data is $phase, expected Bound. Read its events with kubectl describe"
echo "OK: scout-data is Bound"

class=$(kubectl -n "$NS" get pvc scout-data -o jsonpath='{.spec.storageClassName}')
[ "$class" = "standard" ] || fail "scout-data uses class '$class', expected standard"
echo "OK: scout-data uses StorageClass standard"

modes=$(kubectl -n "$NS" get pvc scout-data -o jsonpath='{.spec.accessModes[*]}')
case " $modes " in
  *" ReadWriteMany "*|*" ReadOnlyMany "*) fail "scout-data still asks for a multi-node access mode ($modes)" ;;
esac
echo "OK: access mode is $modes"

# --- 2. the consumer --------------------------------------------------------------
ready=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${ready:-0}" -ge 1 ] || fail "Deployment scout has no ready replica"
echo "OK: scout is ready"

claim=$(kubectl -n "$NS" get deploy scout \
  -o jsonpath='{.spec.template.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}')
[ "$claim" = "scout-data" ] || fail "scout does not use the claim scout-data (found '${claim:-none}'). Do not replace the claim with emptyDir or hostPath"
mount=$(kubectl -n "$NS" get deploy scout \
  -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.mountPath=="/data")].name}')
[ -n "$mount" ] || fail "scout does not mount a volume at /data"
echo "OK: scout mounts scout-data at /data"

# --- 3. the data survives pod replacement ---------------------------------------
marker="grader-$(date +%s)"
old_pod=$(kubectl -n "$NS" get pod -l app=scout --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')
[ -n "$old_pod" ] || fail "no running scout pod"
kubectl -n "$NS" exec "$old_pod" -- sh -c "echo $marker > /data/grader.txt" \
  || fail "could not write to /data in $old_pod"

kubectl -n "$NS" delete pod "$old_pod" --wait=true >/dev/null 2>&1
kubectl -n "$NS" rollout status deploy/scout --timeout=180s >/dev/null 2>&1 \
  || fail "scout did not become ready again after its pod was deleted"

new_pod=""
for _ in $(seq 1 30); do
  new_pod=$(kubectl -n "$NS" get pod -l app=scout --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [ -n "$new_pod" ] && [ "$new_pod" != "$old_pod" ] && break
  sleep 2
done
[ -n "$new_pod" ] && [ "$new_pod" != "$old_pod" ] || fail "no replacement scout pod found"

found=$(kubectl -n "$NS" exec "$new_pod" -- cat /data/grader.txt 2>/dev/null)
[ "$found" = "$marker" ] || fail "the file written before the pod was replaced is missing in $new_pod"
echo "OK: /data/grader.txt survived replacing $old_pod with $new_pod"

echo "PASS: scout keeps its data on a bound claim"
exit 0
