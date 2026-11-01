# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know the HPA replica formula and that the controller picks the highest recommendation of a stabilization window before it scales down.
- Know the shape of `spec.behavior.scaleDown` in `autoscaling/v2`: `stabilizationWindowSeconds`, `selectPolicy` and a list of `policies` with `type`, `value` and `periodSeconds`.

The cluster is a single-node `kind` cluster running Kubernetes 1.35 with metrics-server. The `scout` Deployment runs podinfo 6.15.0 with a CPU request of `100m`. The `shuttle` Deployment has `curl` and sends the test requests.
