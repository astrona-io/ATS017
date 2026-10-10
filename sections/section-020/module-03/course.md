# Provision Storage With StorageClasses

A container's own file system disappears when the container is replaced. A database, a queue or a file upload service needs storage that lives longer than any one pod. Kubernetes gives pods that storage through a chain of three objects, and on most clusters nobody creates the actual volumes by hand any more.

A **PersistentVolumeClaim** (PVC) is a request for storage by size and access mode, written by the application team. A **PersistentVolume** (PV) is one piece of real storage in the cluster. A **StorageClass** names a provisioner, a program that creates a PersistentVolume on demand when a claim asks for that class. This is called dynamic provisioning: the claim comes first, and the volume is created to match it.

Keep one sentence in mind for this module: **the claim belongs to the application, the volume belongs to the cluster, and the StorageClass decides how a volume is created, when it is bound and what happens to it when the claim is gone.** The fields `provisioner`, `volumeBindingMode` and `reclaimPolicy` answer those three questions.

The module has three parts. **StorageClasses And Dynamic Provisioning** reads the StorageClasses in the playground, creates a claim that stays `Pending`, and watches a volume appear when a pod uses it. **Access Modes And Reclaim Policies** proves that data survives a pod restart, shows a claim that the provisioner cannot serve, and deletes claims under the `Delete` and `Retain` policies. **Default Classes And StatefulSets** changes the default StorageClass and gives each replica of a StatefulSet its own claim.

## Learning objectives

After this module you can:

- Read a StorageClass's `provisioner`, `reclaimPolicy`, `volumeBindingMode` and `allowVolumeExpansion` fields.
- Create a PersistentVolumeClaim and explain why it stays `Pending` under `WaitForFirstConsumer` until a pod uses it.
- Mount a claim in a pod and prove that data survives a pod restart.
- Choose an access mode (`ReadWriteOnce`, `ReadOnlyMany`, `ReadWriteMany`, `ReadWriteOncePod`) for a workload.
- Predict what happens to the volume when a claim is deleted under the `Delete` and `Retain` reclaim policies.
- Set the default StorageClass with the `storageclass.kubernetes.io/is-default-class` annotation.

## Before you start

You need Kubernetes basics: pods, Deployments, namespaces and the commands `kubectl get`, `kubectl apply`, `kubectl describe`, `kubectl delete` and `kubectl exec`. You should know that a pod lists its volumes in `spec.volumes` and each container mounts them with `volumeMounts`.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. It has two StorageClasses. `standard` is the default class that `kind` installs; its provisioner, `rancher.io/local-path`, creates each volume as a directory on the node. `standard-retain` uses the same provisioner with the reclaim policy `Retain`. The namespace `starfleet` runs only `shuttle`, a client pod with `curl`, and has no claims yet. The node already holds the `busybox` and `go-httpbin` images that the parts use, so new pods start without a download.

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
