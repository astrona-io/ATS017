# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a container over its memory limit is killed by the kernel and reported as `OOMKilled` with exit code `137`.
- Know that the QoS class comes from requests and limits: `Guaranteed` when every request equals its limit, `Burstable` when at least one request or limit is set but not all equal, `BestEffort` when none is set.

The cluster is a single-node `kind` cluster running Kubernetes 1.35. The `scout` Deployment runs podinfo 6.15.0, which allocates memory on purpose when it starts with `--stress-memory=<MB>`.
