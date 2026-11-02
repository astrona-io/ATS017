# Summary

OpenCost groups cost by the labels of pods, so a workload without the label is charged to nobody, and capacity that nobody requests is charged to the cluster as idle cost. This module followed that sentence from the label on a pod to the cost that a right-sized request moves out of a workload.

## What you learned

A cost report is useful when every dollar has an owner. Showback shows each team what its workloads cost. Chargeback moves that cost to the budget of the team. Both need a label such as `team` on every pod. OpenCost reads pod labels from the Prometheus metric `kube_pod_labels`, so the label must be set under `spec.template.metadata.labels` of a Deployment. A label on the Deployment object alone never reaches the pods. A pod that starts with a new label shows under its team after about five minutes, because Prometheus scrapes once a minute.

The query parameter `aggregate=label:team` groups the cost by the value of the label. The entry `__unallocated__` holds the cost of every pod without that label, and that includes the pods of the system namespaces. The parameter `filter=namespace:"starfleet","outpost"` removes the system pods, so what is left in `__unallocated__` is the list of workloads to label. You can join groupings with a comma, for example `namespace,label:team` or `controller,label:team`. A closed window, written as two Unix timestamps, returns the same numbers every time and keeps the attribution that the pods had when they ran. Adding a label today does not change a report for last week.

Idle cost is a different bucket. It is the cost of node capacity that no pod requests, and it appears as `__idle__` when you add `includeIdle=true`. With `shareIdle=true` OpenCost splits it between the other entries, in proportion to their CPU and memory cost, so each team carries a share of the capacity that nobody uses. A filter by namespace removes `__idle__` before it is shared, so share idle cost on a query without that filter. The parameter `shareNamespaces` has no effect in OpenCost 1.121.3.

Right-sizing lowers the cost of a workload, and on a single node it moves that cost to `__idle__`. The node costs the same, but the capacity is now free for other pods. The saving becomes real when the freed capacity lets you remove a node or run more workloads. The key facts to remember are these:

- OpenCost reads the labels of pods, not of Deployments.
- `__unallocated__` is cost without the label. `__idle__` is capacity without a request.
- A closed window keeps the attribution that the pods had then.
- `shareIdle=true` needs `includeIdle=true` and no namespace filter.
- Lowering a request moves cost to idle cost. Removing capacity lowers the bill.

<!-- astrona:playground:destroy -->
