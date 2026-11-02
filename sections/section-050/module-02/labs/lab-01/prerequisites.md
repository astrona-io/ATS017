# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a PriorityClass has a `value`, and that a pod selects it with `spec.priorityClassName`.
- Know that the scheduler preempts pods with a lower priority only when the new pod does not fit.
- Know how to read the `PodScheduled` condition of a `Pending` pod.

The cluster is a single-node `kind` cluster running Kubernetes 1.35. `scout-critical` runs podinfo 6.15.0 and `probe` runs go-httpbin 2.25.0.
