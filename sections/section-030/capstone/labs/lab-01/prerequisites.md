# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know how to read usage with `kubectl top pods` and how to set requests and limits with `kubectl set resources` or by editing a Deployment.
- Know that an HPA with a CPU `Utilization` target divides usage by the CPU request, and that `behavior.scaleDown.stabilizationWindowSeconds` slows the scale-down.

The cluster is a single-node `kind` cluster running Kubernetes 1.35 with metrics-server. The `scout` Deployment runs podinfo 6.15.0. The `shuttle` Deployment has `curl` and sends the test requests. Prometheus is not installed in this lab.
