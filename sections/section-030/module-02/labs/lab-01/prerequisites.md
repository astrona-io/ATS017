# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that `kubectl top pods` shows the CPU and memory a container uses now, and that a request is what the scheduler reserves.
- Know that a container that goes over its memory limit is killed with `OOMKilled`, and that `kubectl set resources` changes the requests and limits in a Deployment.

The cluster is a single-node `kind` cluster running Kubernetes 1.35 with metrics-server. Both scout Deployments run podinfo 6.15.0. The `shuttle` Deployment sends one request per second to each scout. Prometheus is not installed in this lab.
