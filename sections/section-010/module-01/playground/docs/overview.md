# Overview: Set Requests, Limits And QoS Classes (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with metrics-server and a few copies of the same web application, and then waits. There is no task, no `astrona submit` and no pass or fail. Change resources, push containers past their limits, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it.
- **metrics-server**, which collects CPU and memory usage from the node and serves it to `kubectl top`. The first values for a new pod appear about a minute after it starts.
- Namespace **`starfleet`**:

  | Workload | Resources | QoS class |
  | --- | --- | --- |
  | `scout-guaranteed` | requests and limits `100m` CPU, `64Mi` memory | `Guaranteed` |
  | `scout-burstable` | requests `50m`/`32Mi`, limits `200m`/`128Mi` | `Burstable` |
  | `scout-besteffort` | none | `BestEffort` |
  | `shuttle` | requests `10m`/`16Mi`, memory limit `32Mi` | `Burstable` |

  The `scout` workloads run `podinfo` (`ghcr.io/stefanprodan/podinfo:6.15.0`) on port `9898`. `podinfo` has two start-up flags that load it on purpose: `--stress-cpu=<cores>` keeps that many CPU cores busy, and `--stress-memory=<MB>` loads that many megabytes into memory. Pass them with `args: ["./podinfo", "--stress-cpu=1"]`.
- No LimitRange, no ResourceQuota, no PriorityClass.

## Helpers

Paste these once in each new terminal. `show_qos` prints every pod in `starfleet` with its QoS class. `show_reserved` prints the requests and limits reserved on the node. `last_reason` prints why the container of a pod with the given `app` label last stopped.

```sh
show_qos() {
  kubectl -n starfleet get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
}
show_reserved() {
  kubectl describe nodes | sed -n '/^Allocated resources:/,/^Events:/p'
}
last_reason() {
  kubectl -n starfleet get pods -l app="$1" -o jsonpath='{.items[0].status.containerStatuses[0].lastState}{"\n"}'
}
```

Use them like this: `show_qos`, `show_reserved`, `last_reason scout-memory-hog`.

## Practice tasks

- Add a second container without resources to `scout-guaranteed`. Predict its new QoS class before you check it with `show_qos`.
- Run a `podinfo` copy with `--stress-cpu=2` and no CPU limit. Compare its `kubectl top` value with the copy that has a `200m` limit.
- Find the smallest memory limit at which `--stress-memory=100` stops being `OOMKilled`.
- Work out from `show_reserved` the largest CPU request a new pod can have and still be scheduled. Prove it with one pod that fits and one that stays `Pending`.
- Try to create a pod whose CPU request is larger than its CPU limit, and read the error the API server returns.
