# Right-Size Workloads From Measured Usage

A container's **request** is the amount of CPU or memory that the scheduler reserves for it on a node. Most requests are guesses. A team copies the numbers from another service, or picks a round number such as `1` CPU and `1Gi`, and never looks at them again. Months later the workload uses a few millicores, and the node has no room left for other pods.

The opposite mistake is just as common. A request or a memory **limit** (the most memory a container may use before the kernel kills it) that is too low gives a container that the kernel kills again and again with `OOMKilled`. A wrong request hurts in three places: the scheduler places pods by requests, the HPA divides usage by requests, and cost reports charge for the larger of requests and usage.

**Right-sizing** is the work of changing requests and limits to match what a workload really uses. The data comes from measurements, not from guesses. You read the usage with `kubectl top` and with Prometheus queries over time, you choose new values with a percentile and some headroom, and you apply them. Since Kubernetes 1.35 you can also apply them to a running pod, through **in-place pod resize**, without recreating the pod.

Keep one sentence in mind for this module: **a request should be the measured usage plus headroom, and the Deployment template must hold the final value.** Everything in the parts below either measures the usage, turns it into a number, or applies the number.

The module has six parts. **Measuring Usage With kubectl top And Prometheus** compares requests with usage now and over time. **Choosing Requests And Limits From Usage** turns the measurements into new values and applies them to a Deployment. **Resizing A Running Pod In Place** changes a running container's resources through the `resize` subresource of the pod. **resizePolicy And Resizes That Do Not Finish** controls which resources need a container restart and reads the conditions of a resize that cannot finish. **Making The Change Permanent** puts the final values in the Deployment template. **Right-Sizing Next To An HPA** shows why a CPU autoscaler and a CPU request change must not fight each other.

## Learning objectives

After this module you can:

- Compare a container's requests with its measured usage from `kubectl top` and find over-provisioned and under-provisioned workloads.
- Query usage over time with PromQL (`container_cpu_usage_seconds_total` and `container_memory_working_set_bytes`) and derive a request from a high percentile.
- Resize a running pod's CPU and memory in place with `kubectl patch --subresource resize` and read `status.containerStatuses[].resources`.
- Set `resizePolicy` so that a memory change restarts the container and a CPU change does not, and read the pod's resize conditions.
- Apply the new requests to the Deployment template, and explain why an HPA on CPU and manual CPU right-sizing must not fight each other.

## Before you start

You need Kubernetes basics: pods, Deployments, Services, namespaces, and the commands `kubectl get`, `kubectl apply`, `kubectl describe` and `kubectl patch`. You should know that CPU is written in millicores (`100m` is one tenth of a CPU core), that memory is written in bytes with a suffix such as `Mi`, and what a QoS class is. You should also know what an HPA does.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. It has metrics-server, which serves the usage that `kubectl top` shows, and a small Prometheus that the playground installs with Helm. Prometheus is plumbing here: it only stores the kubelet's usage figures so that you can query them over time. The namespace `starfleet` has these workloads, and no HPA:

| Workload | What it is |
| --- | --- |
| `scout-overprovisioned` | `podinfo`, a small web application, with a CPU request of `1`, a memory request of `1Gi` and a memory limit of `1Gi`, behind the Service `scout-overprovisioned` |
| `scout-underprovisioned` | The same application started with `--stress-memory=150`, so it holds about `160Mi` of memory. Its request is `20m` CPU and `32Mi` memory, with a memory limit of `512Mi` |
| `shuttle` | A client pod with `curl` that sends five requests per second to each scout, so usage data exists from the start |

Give Prometheus about five minutes of samples before you run the queries. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
