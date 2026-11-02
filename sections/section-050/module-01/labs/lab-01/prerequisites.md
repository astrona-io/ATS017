# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a ResourceQuota caps the total requests, limits and object counts of a namespace, and that `kubectl describe resourcequota` shows used against hard.
- Know that a Deployment shows a quota rejection in the events of its ReplicaSet and in its `ReplicaFailure` condition.

The cluster is a single-node `kind` cluster running Kubernetes 1.35. The `probe` Deployment runs go-httpbin 2.25.0.
