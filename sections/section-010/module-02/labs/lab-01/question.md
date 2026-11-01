---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

The cluster has two worker nodes. The worker with the label `topology.kubernetes.io/zone=zone-b` has the taint `dedicated=outpost:NoSchedule`. The `probe` Deployment in the namespace `outpost` selects `zone-b` with a `nodeSelector`, but its pods stay `Pending`.

Find the reason in the pod events, then change `probe` so that:

1.  Both `probe` replicas are `Running` on the `zone-b` node.
2.  The node keeps its taint `dedicated=outpost:NoSchedule`.
3.  The `nodeSelector` for `zone-b` stays in place.
4.  A request from the `shuttle` Deployment in `starfleet` to `http://probe.outpost:8080/status/200` returns HTTP `200`.

Constraints:

* Do not remove or change the taint or the node labels.
* Do not touch the `scout` Deployment. Its pods must not run on the `zone-b` node.

The grader reads the taint, the toleration, the nodes of the `probe` and `scout` pods, and sends the request from `shuttle`.
