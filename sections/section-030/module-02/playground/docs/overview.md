# Overview: Right-Size Workloads From Measured Usage (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with metrics-server, a small Prometheus and three workloads, and then waits. There is no task, no `astrona submit` and no pass or fail. Measure, resize, break, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it. In-place pod resize is part of Kubernetes 1.35, so the `resize` subresource of a pod works without any feature gate.
- **metrics-server**, which collects CPU and memory usage from the kubelet and serves it through the Metrics API to `kubectl top`. The first values for a new pod appear about a minute after it starts.
- **Prometheus**, installed with Helm, in the namespace `monitoring`. It scrapes the kubelet's cAdvisor endpoint every 15 seconds and keeps 2 hours of data. Its Service is `prometheus-server` on port `80`. It has no persistent volume, so the data is gone when the pod restarts.
- Namespace **`starfleet`**:

  | Workload | Resources | What it is |
  | --- | --- | --- |
  | `scout-overprovisioned` | requests `1` CPU and `1Gi` memory, memory limit `1Gi` | `podinfo` (`ghcr.io/stefanprodan/podinfo:6.15.0`) that uses about `1m` CPU and `15Mi` memory |
  | `scout-underprovisioned` | requests `20m` CPU and `32Mi` memory, memory limit `512Mi` | `podinfo` started with `--stress-memory=150`, so it holds about `160Mi` of memory |
  | `shuttle` | requests `10m`/`16Mi`, memory limit `32Mi` | A client pod with `curl` that sends one request to each scout every second |

- No HPA, no LimitRange, no ResourceQuota.

## Helpers

Paste this once in each new terminal. `query_prometheus` sends a PromQL query to Prometheus from the `shuttle` pod and prints the JSON answer.

```sh
query_prometheus() {
  kubectl -n starfleet exec deploy/shuttle -- \
    curl -s --get http://prometheus-server.monitoring.svc/api/v1/query \
    --data-urlencode "query=$1"
  echo
}
```

## Practice tasks

- Compare the requests of each scout with `kubectl top pods` and decide which one wastes capacity and which one is at risk.
- Wait 10 minutes, then query the peak memory and the 95th percentile of CPU of each scout over the whole window.
- Resize the CPU request of `scout-overprovisioned` in place, and prove from the pod UID and `restartCount` that the container did not restart.
- Add a `resizePolicy` with `RestartContainer` for memory to the Deployment, resize the memory in place, and watch `restartCount` change.
- Ask for a CPU request larger than the node and read the `PodResizePending` condition.
- Add an HPA to `scout-overprovisioned`, change its CPU request, and watch the utilisation figure change.
