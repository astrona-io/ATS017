# Overview: Read Cost Allocation With OpenCost (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a small Prometheus, OpenCost and five workloads, and then waits. There is no task, no `astrona submit` and no pass or fail. Query, compare, break, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it. A `kind` cluster has no cloud bill, so every cost here comes from a fixed price list, not from real invoices.
- **metrics-server**, which serves `kubectl top`.
- **Prometheus**, installed with Helm, in the namespace `monitoring`. It scrapes the kubelet's cAdvisor endpoint, kube-state-metrics and OpenCost every minute and keeps 6 hours of data. Its Service is `prometheus-server` on port `80`.
- **OpenCost** `1.121.3`, installed with Helm, in the namespace `opencost`. It reads from Prometheus and uses the default on-premises price list: `0.031611` dollars per CPU core hour, `0.004237` dollars per GiB hour of memory and `0.00005479452` dollars per GiB hour of storage. Its allocation API listens on port `9003` and its UI on port `9090`.
- Namespace **`starfleet`**:

  | Workload | Resources | What it is |
  | --- | --- | --- |
  | `scout` | requests `100m` CPU and `64Mi` memory | `podinfo` (`ghcr.io/stefanprodan/podinfo:6.15.0`) that uses almost nothing |
  | `scout-busy` | requests `50m` and `64Mi`, limits `400m` and `256Mi` | `podinfo` started with `--stress-cpu=1` and `--stress-memory=100`, so it uses more CPU than it requests |
  | `probe` | requests `50m` and `32Mi` | `go-httpbin` (`mccutchen/go-httpbin:2.25.0`) |
  | `shuttle` | requests `10m` and `16Mi` | A client pod with `curl` that sends a request to `scout` and `probe` in a loop |

- Namespace **`outpost`**: `probe` with requests `200m` and `256Mi`, and a PersistentVolumeClaim named `archive` (`20Gi`) that the pod mounts.

OpenCost needs about 6 minutes of samples before the first cost appears, and about 15 minutes before the numbers settle. Early answers can be empty or can contain odd values.

## Helpers

Paste this once in each new terminal. `query_prometheus` sends a PromQL query to Prometheus from the `shuttle` pod. `query_opencost` sends a request to the OpenCost allocation API through the Kubernetes API server.

```sh
query_prometheus() {
  kubectl -n starfleet exec deploy/shuttle -- \
    curl -s --get http://prometheus-server.monitoring.svc/api/v1/query \
    --data-urlencode "query=$1"
  echo
}
query_opencost() {
  kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?$1"
}
```

## Practice tasks

- Ask for the cost of the last hour of each namespace with `aggregate=namespace`, and find which namespace costs more.
- Ask for the cost of each Deployment with `aggregate=namespace,controller` and find the one with the highest `totalEfficiency`.
- Compare the `cpuCores` charged to `scout-busy` with its request, and explain why they differ.
- Find the storage cost of the `archive` volume in `outpost`.
- Add `includeIdle=true` to a query and read the `__idle__` entry.
- Forward port `9090` of the `opencost` Service and open the UI.
