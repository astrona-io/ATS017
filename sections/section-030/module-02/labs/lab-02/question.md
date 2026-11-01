---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

The `scout` pod in the namespace `starfleet` holds its working data in memory, so it must not restart. The Deployment `scout` owns the pod. The container has a CPU request of `100m`, a CPU limit of `200m`, a memory request of `64Mi` and a memory limit of `128Mi`. The `shuttle` Deployment in the same namespace is a client with `curl`.

The pod needs more CPU now. Change the **running pod** so that:

1.  The container of the same pod (the same UID) has a CPU request of `500m` and a CPU limit of `1`.
2.  The container is not restarted: `restartCount` stays `0`.
3.  `status.containerStatuses[0].resources` shows the new CPU request and limit, and the pod has no resize condition left.
4.  The memory request and limit stay `64Mi` and `128Mi`.

Constraints:

* Do not edit the Deployment, delete the pod or scale the Deployment. A new pod would have a new UID.

The grader compares the UID of the pod with the one recorded when the lab started, reads `restartCount`, and reads the resources and conditions from the pod status.
