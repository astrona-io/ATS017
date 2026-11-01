# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a pod can change the CPU and memory of its containers in place, through the pod's `resize` subresource, without being recreated.
- Know that `kubectl patch --subresource resize` sends the change, and that `status.containerStatuses[].resources` shows what the container runs with.

The cluster is a single-node `kind` cluster running Kubernetes 1.35 with metrics-server. The `scout` Deployment runs podinfo 6.15.0. The `shuttle` Deployment has `curl`.
