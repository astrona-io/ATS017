# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a PersistentVolume copies its reclaim policy from the StorageClass when it is created, and keeps its own copy afterwards.
- Know that the annotation `storageclass.kubernetes.io/is-default-class` marks the default StorageClass.

The cluster is a single-node `kind` cluster running Kubernetes 1.35 with two StorageClasses: `standard` (default, reclaim policy `Delete`) and `standard-retain` (reclaim policy `Retain`). Both use `WaitForFirstConsumer` binding.
