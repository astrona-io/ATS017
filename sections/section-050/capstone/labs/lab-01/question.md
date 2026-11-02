---
estimated_duration: 45m
---

# Question

Solve this question on: `terminal`

The `starfleet` and `outpost` namespaces share one node. Three things are wrong:

* The Deployment `scout-critical` in `starfleet` requests `300m` CPU and stays `Pending`, because the `probe` pods in `outpost` use the free CPU.
* The Deployment `batch-worker` in `outpost` has no pods. The ResourceQuota `outpost-quota` requires memory requests and limits, and the pods set none.
* Teams will soon use the PriorityClass `platform-high` in every namespace. Only `starfleet` may use it.

Do these tasks:

1.  Create a PriorityClass named `platform-high` with value `100000` and make `scout-critical` use it, so the pod runs because the scheduler preempts a `probe` pod.
2.  Make the two `batch-worker` pods run without changing the Deployment: set a default memory request and a default memory limit for every container in `outpost`.
3.  Make the quota system reject any pod of the class `platform-high` in `outpost`. Pods without a class in `outpost`, and pods of `platform-high` in `starfleet`, must still be accepted.

Constraints:

* Do not change, scale or delete the `probe` Deployment.
* Do not change, raise or delete `outpost-quota`.
* Do not change the resources of `scout-critical` or `batch-worker`.

The grader checks that `scout-critical` is Ready and a `Preempted` event exists, that two `batch-worker` pods are Ready and a LimitRange sets the defaults, and that it can create pods in both namespaces with the results above.
