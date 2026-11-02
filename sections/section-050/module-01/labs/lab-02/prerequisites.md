# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a compute ResourceQuota rejects a pod that does not declare the requests and limits the quota counts.
- Know the LimitRange fields `defaultRequest`, `default`, `min` and `max` for `type: Container`.
- Know that a LimitRange changes only pods created after it, and that `kubectl rollout restart` makes a Deployment create its pods again at once.

The cluster is a single-node `kind` cluster running Kubernetes 1.35. The `batch-worker` Deployment runs go-httpbin 2.25.0.
