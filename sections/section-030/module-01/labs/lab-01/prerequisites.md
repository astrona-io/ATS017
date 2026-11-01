# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a HorizontalPodAutoscaler (HPA) with a CPU `Utilization` target divides the CPU a pod uses by the CPU the pod requests.
- Know that `kubectl describe hpa` shows the conditions and events that explain a target the HPA cannot read.

The cluster is a single-node `kind` cluster running Kubernetes 1.35 with metrics-server. The `scout` Deployment runs podinfo 6.15.0. The `shuttle` Deployment has `curl` and sends the test requests.
