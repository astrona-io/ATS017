# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know how a PriorityClass gives a pod a priority and how the scheduler preempts lower-priority pods when a pod does not fit.
- Know that a LimitRange sets default requests and limits for containers that do not set them, and that this happens before the ResourceQuota check.
- Know that a ResourceQuota with `scopeSelector` and the scope `PriorityClass` counts only pods of the named classes.

The cluster is a single-node `kind` cluster running Kubernetes 1.35.
