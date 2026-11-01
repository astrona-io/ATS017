# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know how to read a claim's events with `kubectl describe pvc`.
- Know that a pod mounts a PersistentVolumeClaim through `spec.volumes` and `volumeMounts`.
- Know that `accessModes` on a claim cannot be edited after the claim is created.

The cluster is a single-node `kind` cluster running Kubernetes 1.35. Its default StorageClass is `standard`, which uses the `rancher.io/local-path` provisioner and `WaitForFirstConsumer` binding.
