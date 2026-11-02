# Provision Storage With StorageClasses

A container's writable file system does not survive container replacement. An application that stores files needs a volume that lives longer than its pod. Kubernetes lets the application request that storage without choosing a directory or disk itself.

A **PersistentVolumeClaim** (PVC) is a namespaced request for storage by size and access mode. A **PersistentVolume** (PV) is a cluster-wide object that represents storage. A **StorageClass** names a provisioner, the component that creates storage on demand, and sets the rules for binding and reclaiming it. Creating a volume to meet a claim is called **dynamic provisioning**.

Keep one sentence in mind for this module: **the application requests a claim, the provisioner creates a volume, and the kubelet mounts that volume into the pod.** The kubelet is the Kubernetes agent on each node. A claim can survive pod replacement, but whether its storage survives claim deletion depends on the volume's reclaim policy.

The module has six parts. **StorageClasses And Dynamic Provisioning** reads the classes and binds a claim only when a pod needs it. **Persistent Data And ReadWriteOnce** replaces a pod, reads the saved file, and mounts one claim in two pods on the same node. **Unsupported Access Modes** asks for a sharing mode the storage cannot provide and reads the event that says why. **Delete And Retain Reclaim Policies** deletes claims and compares the remaining volumes. **Changing The Default StorageClass** moves the default mark from one class to another and shows which class a claim without `storageClassName` receives. **StatefulSet Claims** creates one claim per replica with a StatefulSet, a controller that gives pods stable names and storage.

## Learning objectives

After this module you can:

- Read a StorageClass's `provisioner`, `reclaimPolicy`, `volumeBindingMode` and `allowVolumeExpansion` fields.
- Create a PersistentVolumeClaim and explain why it stays `Pending` under `WaitForFirstConsumer` until a pod uses it.
- Mount a claim in a pod and prove that data survives pod replacement.
- Choose an access mode: `ReadWriteOnce`, `ReadOnlyMany`, `ReadWriteMany` or `ReadWriteOncePod`.
- Predict what happens to a volume when its claim is deleted under `Delete` and `Retain` reclaim policies.
- Set the default StorageClass and use `volumeClaimTemplates` for one claim per StatefulSet replica.

## Before you start

You need Kubernetes basics: pods, namespaces, Services, Deployments, and the commands `kubectl get`, `kubectl apply`, `kubectl describe`, `kubectl delete` and `kubectl exec`. A pod declares a volume in `spec.volumes`, and a container mounts it at a path with `volumeMounts`.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. Its provisioner, `rancher.io/local-path`, creates directories on the node. It has these starting objects:

| Object | What it provides |
| --- | --- |
| StorageClass `standard` | The default class, with `WaitForFirstConsumer`, reclaim policy `Delete` and no volume expansion |
| StorageClass `standard-retain` | The same binding mode, with reclaim policy `Retain` |
| Namespace `starfleet` | The namespace for your claims and pods |
| Deployment `shuttle` | A client pod with `curl` |

No claims exist at the start. The node already holds the `busybox:1.37` and `mccutchen/go-httpbin:2.25.0` images used in the examples. Local storage survives pod replacement on this node; destroying the playground removes the node and its data.

Write each example file on your own machine. Every command runs against the playground cluster, and `kubectl` already points at it. Read the pages in order and keep the objects until the commands remove them.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
