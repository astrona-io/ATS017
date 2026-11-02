# Summary

A full cluster needs two answers: which pod wins the last CPU, and how many pods of each kind a tenant may run. This module covered both.

## What you learned

A PriorityClass is a cluster-wide object with an integer `value`. A pod selects it with `priorityClassName`, and the API server copies the number into `spec.priority`. A pod without a class gets `0`, unless one class sets `globalDefault: true`. The two system classes, `system-cluster-critical` and `system-node-critical`, are reserved for Kubernetes components.

When a pod does not fit, kube-scheduler looks for pods with a lower priority to evict. It writes a `Preempted` event on each victim and places the new pod. If every other pod has the same priority, the message says `No preemption victims found`. A class with `preemptionPolicy: Never` keeps its number but never evicts, and the pod stays `Pending` with the message `not eligible due to preemptionPolicy=Never`.

A quota scope makes a ResourceQuota count only some pods. The `PriorityClass` scope, with a `scopeSelector`, limits how many pods use a class. The `BestEffort` scope with `pods: "0"` forbids pods without resources. A pod must pass every quota that matches it.

- Preemption needs a priority gap and a full node.
- A preempted pod is deleted, and its Deployment creates a replacement that may stay `Pending`.
- `preemptionPolicy: Never` removes the right to evict, not the priority.
- A scoped quota is a separate budget for one kind of pod.

<!-- astrona:playground:destroy -->
