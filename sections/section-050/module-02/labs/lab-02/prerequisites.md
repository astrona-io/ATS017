# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a ResourceQuota can have a scope, and that the scope `PriorityClass` needs a `scopeSelector`.
- Know that the scope `BestEffort` matches pods that declare no requests and no limits, and that it can only limit `pods`.

The cluster is a single-node `kind` cluster running Kubernetes 1.35. The `beacon` Deployment runs go-httpbin 2.25.0.
