# Overview: Scale Workloads With The HorizontalPodAutoscaler (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with metrics-server and three workloads, and then waits. There is no task, no `astrona submit` and no pass or fail. Create an HPA, load it, change it, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it.
- **metrics-server**, which collects CPU and memory usage from the kubelet and serves it through the Metrics API to `kubectl top` and to the HPA. The first values for a new pod appear about a minute after it starts.
- Namespace **`starfleet`**:

  | Workload | Resources | What it is |
  | --- | --- | --- |
  | `scout` | requests `100m` CPU and `32Mi` memory, memory limit `64Mi` | `podinfo` (`ghcr.io/stefanprodan/podinfo:6.15.0`) on port `9898`, behind the Service `scout` on port `80` |
  | `scout-norequests` | none | The same application with no resources, behind the Service `scout-norequests` |
  | `shuttle` | requests `10m`/`16Mi`, memory limit `32Mi` | A client pod with `curl` |

- No HPA, no LimitRange, no ResourceQuota.

## Helpers

Paste these once in each new terminal. `load_scout` sends requests from `shuttle` to a Service for 150 seconds, from four parallel `curl` processes. `show_hpa` prints the HPA, its pods and their usage.

```sh
load_scout() {
  kubectl -n starfleet exec deploy/shuttle -- sh -c \
    "for i in 1 2 3 4; do timeout 150 curl -s -o /dev/null -X POST 'http://$1/token?[1-5000000]' & done; wait"
}
show_hpa() {
  kubectl -n starfleet get hpa
  kubectl -n starfleet top pods
}
```

Use them like this: `load_scout scout` in one terminal and `kubectl -n starfleet get hpa --watch` in another.

## Practice tasks

- Create an HPA for `scout` with a target of `50` percent, start `load_scout scout`, and predict the replica count with the formula before you read it.
- Create an HPA for `scout-norequests`, read the `<unknown>` target, and find the condition and the event that explain it.
- Change `averageUtilization` to `200` and watch how many replicas the same load needs.
- Add `behavior.scaleDown.stabilizationWindowSeconds: 60`, stop the load, and time the scale-down.
- Run `kubectl top pods` during the load and find the one pod that receives all the requests.
