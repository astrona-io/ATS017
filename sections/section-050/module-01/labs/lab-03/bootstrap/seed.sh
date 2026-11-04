#!/usr/bin/env bash
# Create the repository and cluster starting state each time the lab starts.
set -euo pipefail
cd "$(dirname "$0")"
bash ./install-git.sh
# The learner's own Git settings (hooks, signing, default branch) must not affect the seed.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
review_dir=/tmp/cnpe-pipeline-review
# This path belongs to the lab, so a new start replaces it.
rm -rf "$review_dir"
mkdir -p "$review_dir/pipelines"
git -C "$review_dir" init -q
git -C "$review_dir" symbolic-ref HEAD refs/heads/main
git -C "$review_dir" config user.name 'Starfleet Platform'
git -C "$review_dir" config user.email 'platform@starfleet.example'
for namespace in pipeline-scout pipeline-probe pipeline-shuttle; do
  cat > "$review_dir/pipelines/${namespace}.yaml" <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pipeline-cache
  namespace: ${namespace}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: standard
  resources:
    requests:
      storage: 1Gi
YAML
done
git -C "$review_dir" add pipelines
git -C "$review_dir" commit -q -m 'Record pipeline cache claims'
# Only the historical commit requests the large volume. No large PVC is applied.
sed 's/storage: 1Gi/storage: 80Gi/' "$review_dir/pipelines/pipeline-shuttle.yaml" > "$review_dir/request.yaml"
mv "$review_dir/request.yaml" "$review_dir/pipelines/pipeline-shuttle.yaml"
git -C "$review_dir" add pipelines/pipeline-shuttle.yaml
git -C "$review_dir" commit -q -m 'Request expanded pipeline cache'
git -C "$review_dir" revert --no-edit HEAD >/dev/null
kubectl apply -f manifests/lab-start.yaml
for namespace in pipeline-scout pipeline-probe pipeline-shuttle; do
  kubectl -n "$namespace" rollout status deployment/cache-reader --timeout=180s
done
echo "Repository: $review_dir"
