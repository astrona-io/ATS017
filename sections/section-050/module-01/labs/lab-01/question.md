---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

The Deployment `probe` in the namespace `outpost` is set to run `4` replicas, but only `2` pods run. The namespace has a ResourceQuota named `outpost-quota`. The other two pods are never created.

Find out why, and change the Deployment so that:

1.  All `4` replicas of `probe` are `Ready`.
2.  The `probe` container has a CPU **request** of at least `50m` and at most `120m`.
3.  The Deployment still has `4` replicas.

Constraints:

* Do not change, replace or delete the ResourceQuota `outpost-quota`. It is the share of the namespace and it stays as it is.
* Do not scale `probe` down and do not remove the CPU request. The quota requires every container to declare requests.

The grader reads the quota and the Deployment, waits for four ready pods, and then creates a pod that asks for `1` CPU in `outpost`. The quota must still reject that pod.
