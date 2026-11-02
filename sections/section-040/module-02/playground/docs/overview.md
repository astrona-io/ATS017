# Overview: Attribute Cost By Label And Find Idle Spend (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a small Prometheus, OpenCost and six workloads that carry cost-attribution labels, and then waits. There is no task, no `astrona submit` and no pass or fail. Query, compare, break, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it. A `kind` cluster has no cloud bill, so every cost here comes from a fixed price list, not from real invoices.
- **metrics-server**, which serves `kubectl top`.
- **Prometheus**, installed with Helm, in the namespace `monitoring`. It scrapes the kubelet's cAdvisor endpoint, kube-state-metrics and OpenCost every minute and keeps 6 hours of data. Its Service is `prometheus-server` on port `80`.
- **OpenCost** `1.121.3`, installed with Helm, in the namespace `opencost`. It reads from Prometheus and uses the default on-premises price list: `0.031611` dollars per CPU core hour, `0.004237` dollars per GiB hour of memory and `0.00005479452` dollars per GiB hour of storage. Its allocation API listens on port `9003` and its UI on port `9090`.
- Namespace **`starfleet`**:

  | Workload | Label `team` | Requests | What it is |
  | --- | --- | --- | --- |
  | `scout` | `navigation` | `100m` CPU, `64Mi` memory | `podinfo` (`ghcr.io/stefanprodan/podinfo:6.15.0`) that uses almost nothing |
  | `probe` | `navigation` | `50m`, `32Mi` | `go-httpbin` (`mccutchen/go-httpbin:2.25.0`) |
  | `shuttle` | `navigation` | `10m`, `16Mi` | A client pod with `curl` that sends a request to `scout` and `probe` in a loop |
  | `scout-overprovisioned` | `science` | `1500m`, `1Gi` | `podinfo` that requests far more than it uses |

- Namespace **`outpost`**:

  | Workload | Label `team` | Requests | What it is |
  | --- | --- | --- | --- |
  | `probe` | `research` | `100m`, `64Mi` | `go-httpbin` |
  | `archive` | none | `300m`, `256Mi` | `go-httpbin`. This is the deliberate gap: no pod of this Deployment has a `team` label |

OpenCost needs about 6 minutes of samples before the first cost appears, and about 15 minutes before the numbers settle. A pod that starts later, for example after you change a Deployment, appears in OpenCost with its new labels about 5 minutes after it starts.

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

- Ask for the cost of the last hour with `aggregate=label:team` and find the bucket `__unallocated__`. List which workloads fall into it.
- Add `filter=namespace:"starfleet","outpost"` and see which part of `__unallocated__` is left.
- Add the label `team: operations` to the pod template of `archive` and wait for OpenCost to show it under `operations`.
- Add `includeIdle=true` and `shareIdle=true` and compare the team totals.
- Find the workload with the lowest `totalEfficiency`, lower its requests with `kubectl set resources` and compare two closed windows.
- Try `shareNamespaces=kube-system` and compare the totals with and without it.
