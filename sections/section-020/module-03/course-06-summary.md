# Summary

A PersistentVolumeClaim (PVC) is a namespaced storage request. A PersistentVolume (PV) represents storage at cluster scope, and a StorageClass selects the provisioner and the rules for new volumes. Dynamic provisioning creates a volume to meet a claim, while the kubelet mounts that volume into a consuming pod.

`WaitForFirstConsumer` delays provisioning and binding until the scheduler can choose a suitable node for a pod. A claim waiting without a consumer is therefore normal. Once a consumer exists, claim events distinguish successful provisioning from an unsupported access mode or another storage failure. Local volume node affinity restricts consumers to the node that holds the files.

Files on a mounted claim survive pod replacement while that claim and its backing storage remain. `ReadWriteOnce` means read-write access from one node and can allow several pods on that node. `ReadOnlyMany` and `ReadWriteMany` describe multi-node access, while `ReadWriteOncePod` restricts access to one pod. The storage implementation must support the selected mode.

Deleting a claim triggers its volume's reclaim policy. `Delete` removes the volume and backing storage; `Retain` leaves a `Released` volume for manual recovery or cleanup. A retained volume still holds its old claim reference. Retention is not a backup and does not protect local data against loss of the node.

The default StorageClass supplies a class when a claim omits `storageClassName`; an explicit empty string requests no class. StatefulSet claim templates create one claim per replica with a stable name. StatefulSets keep those claims on scale-down and deletion by default, which is a separate decision from the PV reclaim policy.

<!-- astrona:playground:destroy -->
