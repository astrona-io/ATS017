# Overview: Share Capacity With PriorityClasses And Quota Scopes (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a full node and then waits. There is no task, no `astrona submit` and no pass or fail.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it.
- Namespace **`starfleet`**: `shuttle` (requests `10m` CPU and `16Mi` memory, memory limit `32Mi`).
- Namespace **`outpost`**: `probe` with three replicas. Each requests the same amount of CPU, sized so that about `150m` of CPU stays free on the node.
- Only the built-in PriorityClasses `system-cluster-critical` and `system-node-critical`. No ResourceQuota.

## Practice tasks

- Create a pod in `starfleet` that requests `300m` of CPU and read why it stays `Pending`.
- Create a PriorityClass, give it to that pod, and read the `Preempted` event.
- Create a class with `preemptionPolicy: Never` and show that its pod stays `Pending`.
- Add a quota with the scope `PriorityClass` and allow one pod of the class.
- Add a quota with the scope `BestEffort` and `pods: "0"`, then create a pod without resources.
