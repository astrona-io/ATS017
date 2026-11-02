---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

The Deployment `batch-worker` in the namespace `outpost` has `3` replicas, but no pod runs. The ResourceQuota `outpost-quota` in the namespace requires every container to declare CPU and memory requests and a memory limit. The team that owns `batch-worker` cannot change the Deployment, and the quota must not change either.

Make the namespace give default resources to containers that declare none, so that:

1.  All `3` pods of `batch-worker` are `Ready`, and each container gets a CPU request of `50m`, a memory request of `64Mi` and a memory limit of `128Mi`.
2.  A container in `outpost` cannot ask for a memory limit above `256Mi`. The API server rejects such a pod.
3.  A new pod without any resources is accepted and gets the same defaults.

Constraints:

* Do not edit the pod template of the Deployment `batch-worker`.
* Do not change, replace or delete the ResourceQuota `outpost-quota`.

The grader reads the Deployment and the quota, waits for three ready pods, creates a pod without resources and a pod with a `512Mi` memory limit, and reads the result of each.
