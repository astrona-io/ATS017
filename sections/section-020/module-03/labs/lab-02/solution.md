# Solution Walkthrough

A volume keeps its own `persistentVolumeReclaimPolicy` after it is created. Changing a StorageClass does not change it, and the `reclaimPolicy` of a class cannot be edited. You patch the volume itself, then move the default mark between the two classes.

---

## Step 1: Find the volume behind the claim

```sh
PROBE_VOLUME=$(kubectl -n starfleet get pvc probe-data -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PROBE_VOLUME" -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,RECLAIM:.spec.persistentVolumeReclaimPolicy,CLAIM:.spec.claimRef.name
```

The `RECLAIM` column shows `Delete`.

## Step 2: Change the policy on the volume

```sh
kubectl patch pv "$PROBE_VOLUME" -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
kubectl get pv "$PROBE_VOLUME" -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy
```

The `RECLAIM` column now shows `Retain`. The claim and the pod do not change.

## Step 3: Move the default mark

```sh
kubectl annotate storageclass standard storageclass.kubernetes.io/is-default-class=false --overwrite
kubectl annotate storageclass standard-retain storageclass.kubernetes.io/is-default-class=true --overwrite
kubectl get storageclass
```

Only `standard-retain` shows `(default)`.

## Step 4: Check the file and submit

```sh
kubectl -n starfleet exec probe-storage -- cat /data/message.txt
astrona submit -c sections/section-020/module-03/labs/lab-02
```

The file prints `saved-by-probe`.

## Why the other fixes fail

- **Deleting the claim and creating a new one on `standard-retain`.** The old volume is deleted with its file. The grader reads the file from the original pod.
- **Editing the `reclaimPolicy` of `standard`.** The API server rejects the change, and it would not change existing volumes anyway.
- **Marking both classes as default.** Kubernetes then picks the newest class for claims without a class, and the grader requires exactly one default.
