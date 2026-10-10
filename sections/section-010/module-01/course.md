# Set Requests, Limits And QoS Classes

A pod stays `Pending` although the cluster looks almost empty. Another pod restarts every few seconds with the reason `OOMKilled`. A third one answers slowly, but its CPU graph is a flat line at exactly `200m`. All three problems come from the same two fields on a container: `resources.requests` and `resources.limits`.

A **request** is the amount of CPU or memory the scheduler reserves for a container on a node. A **limit** is the most CPU or memory the container may use while it runs. The two fields look alike, but different components read them at different times, and they fail in different ways. Almost everything else on a platform builds on them: the scheduler places pods by requests, the HorizontalPodAutoscaler scales on usage measured against requests, cost tools split node prices by requests, and quotas count requests.

Keep one sentence in mind for this module: **the scheduler reads requests once, before the pod starts; the kernel enforces limits all the time, while the container runs.**

The module has four parts. **Requests, Limits And Who Reads Them** sets both fields on a container, reads them back, and follows them from the scheduler to the Linux kernel. **What Happens At The Limit** runs one container that wants too much CPU and one that wants too much memory, and shows the very different results. **QoS Classes And Eviction** derives each pod's Quality of Service class from its resources and explains which pods the node removes first when memory runs short. **Node Capacity And Pending Pods** reads what a node can offer and what is already reserved, and diagnoses a pod that fits nowhere.

## Learning objectives

After this module you can:

- Set CPU and memory requests and limits on a container and read them back with `kubectl get -o yaml`.
- Predict the QoS class (`Guaranteed`, `Burstable`, `BestEffort`) of a pod from its resources and confirm it in `status.qosClass`.
- Diagnose a `Pending` pod whose requests do not fit any node from its `FailedScheduling` event.
- Tell apart a container killed for going over its memory limit (`OOMKilled`) and a CPU-throttled container.
- Compare a node's allocatable capacity with the sum of requests using `kubectl describe node`.
- Find the `resources` fields with `kubectl explain` and in the Kubernetes resource management documentation.

## Before you start

You need Kubernetes basics: pods, Deployments, namespaces, and the commands `kubectl get`, `kubectl apply`, `kubectl describe` and `kubectl exec`. You do not need to know anything about Linux control groups; the parts explain the one detail that matters.

Your playground is a single-node `kind` cluster running Kubernetes 1.35, with metrics-server installed. metrics-server collects CPU and memory usage from each node and serves it to `kubectl top`. The namespace `starfleet` runs these workloads:

| Workload | What it is |
| --- | --- |
| `scout-guaranteed` | `podinfo` with requests equal to limits (`100m` CPU, `64Mi` memory) |
| `scout-burstable` | `podinfo` with requests below limits (`50m`/`32Mi` requested, `200m`/`128Mi` limit) |
| `scout-besteffort` | `podinfo` with no resources at all |
| `shuttle` | A client pod with `curl` |

`podinfo` is a small web application on port `9898`. It also has two start-up flags, `--stress-cpu` and `--stress-memory`, that make it use a lot of CPU or memory on purpose; the parts use them to push a container to its limits. There is no LimitRange or ResourceQuota in the cluster, so nothing adds or checks resources for you. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
