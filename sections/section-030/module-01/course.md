# Scale Workloads With The HorizontalPodAutoscaler

A Deployment with a fixed replica count is wrong most of the day. At night it wastes the CPU and memory its replicas request; at the busiest hour it has too few replicas and requests slow down. Changing the count by hand does not scale with the number of workloads on a platform.

A **HorizontalPodAutoscaler** (HPA) is a Kubernetes object, and a controller in the control plane, that changes a workload's replica count to keep a metric near a target. The most common metric is CPU utilisation: the CPU a pod uses, as a percentage of the CPU it requests. The HPA reads that usage from the Metrics API, which metrics-server provides.

Keep one sentence in mind for this module: **the HPA scales on usage divided by requests, so a pod without a CPU request cannot be scaled on CPU at all.** Requests are not only for the scheduler; they are also the yardstick the autoscaler measures against.

The module has three parts. **The Metrics API And kubectl top** reads live CPU and memory usage and shows where it comes from. **Writing An HPA And Its Replica Formula** creates an `autoscaling/v2` HPA, generates load from inside the cluster, and checks each scaling step against the formula the controller uses. **Unknown Targets And Scaling Behavior** diagnoses an HPA that shows `<unknown>`, and slows down scale-down with a stabilization window and a policy.

## Learning objectives

After this module you can:

- Create an `autoscaling/v2` HPA with a CPU utilisation target and `minReplicas` and `maxReplicas`.
- Calculate the desired replica count from current and target utilisation with the HPA formula.
- Generate load from inside the cluster and watch the HPA scale up and back down with `kubectl get hpa --watch`.
- Diagnose an HPA that shows `<unknown>` targets because the pods have no CPU requests or the Metrics API is missing.
- Slow down scale-down with `behavior.scaleDown.stabilizationWindowSeconds` and policies.

## Before you start

You need Kubernetes basics: pods, Deployments, Services, namespaces, and the commands `kubectl get`, `kubectl apply`, `kubectl describe` and `kubectl scale`. You should know that a container's CPU request is the amount of CPU the scheduler reserves for it, written in millicores (`100m` is one tenth of a CPU core).

Your playground is a single-node `kind` cluster running Kubernetes 1.35 with metrics-server installed, so `kubectl top` and the HPA have data. The namespace `starfleet` has these workloads, and no HPA yet:

| Workload | What it is |
| --- | --- |
| `scout` | `podinfo`, a small web application, with one replica and a CPU request of `100m`, behind the Service `scout` |
| `scout-norequests` | The same application with no resources set at all, behind the Service `scout-norequests` |
| `shuttle` | A client pod with `curl` |

The first `kubectl top` values appear about a minute after the cluster starts. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
