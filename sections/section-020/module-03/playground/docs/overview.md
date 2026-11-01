# Overview: Provision Storage With StorageClasses (Playground)

This playground starts a fresh cluster with two storage classes and no claims. A StorageClass selects the provisioner and the rules for creating storage. Create claims and consumers, write files, replace pods, and inspect what remains when claims are removed. There is no grading or submission.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35, with `kubectl` already pointed at it.
- StorageClass `standard`, the default, with `WaitForFirstConsumer` binding and reclaim policy `Delete`.
- StorageClass `standard-retain`, with the same binding mode and reclaim policy `Retain`.
- Namespace `starfleet` with `shuttle`, a client pod with `curl`, and no PersistentVolumeClaims yet.
- Preloaded `busybox:1.37` and `mccutchen/go-httpbin:2.25.0` images for file tests and the `probe` StatefulSet example.

A PersistentVolumeClaim (PVC) requests storage in a namespace; a PersistentVolume (PV) represents its backing storage at cluster scope. The playground provisioner creates directories on the node. Its storage does not expand or support `ReadWriteMany`; checked claims with `ReadWriteOnce` and `ReadWriteOncePod` bind successfully. Removing the cluster removes its local data, including retained volumes.

The `probe` StatefulSet example creates one claim per replica through `volumeClaimTemplates`. A StatefulSet is a controller that gives pods stable names and storage. Its manifest is available to authors but is not applied at startup, so the learner creates the claims themselves.

## Helpers

Paste these once in each new terminal. `show_claims` lists namespace storage requests and their bindings. `show_volumes` lists volume phases and reclaim policies. `read_storage_file` reads a file from a running pod's mount.

```sh
show_claims() {
  kubectl -n starfleet get pvc -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,CLASS:.spec.storageClassName,VOLUME:.spec.volumeName
}
show_volumes() {
  kubectl get pv -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,RECLAIM:.spec.persistentVolumeReclaimPolicy,CLAIM:.spec.claimRef.name
}
read_storage_file() {
  kubectl -n starfleet exec "$1" -- cat "$2"
}
```

Use them like this: `show_claims`, `show_volumes`, `read_storage_file scout-storage /data/message.txt` after that pod and file exist.

## Practice tasks

- Create a claim with `standard` and inspect its events before and after creating a consuming pod.
- Write a file to a mounted claim, replace the pod, and prove that the new pod reads the same file.
- Mount one `ReadWriteOnce` claim in two pods on this node, then compare that with two consumers of a `ReadWriteOncePod` claim.
- Compare a claim that omits `storageClassName` with a claim that explicitly sets it to an empty string.
- Create one volume with each reclaim policy, remove their consumers and claims, and inspect which volume remains.
- Create two StatefulSet replicas with a claim template, scale down, and count the claims that remain.
