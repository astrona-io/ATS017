---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

Two Deployments in the namespace `starfleet` have the wrong resources. The `shuttle` Deployment in the same namespace is a client with `curl` that sends one request per second to each of them.

* `scout-overprovisioned` requests far more CPU and memory than the container uses.
* `scout-underprovisioned` is restarted again and again. `kubectl describe pod` shows the reason `OOMKilled`. The container starts with the argument `--stress-memory=100`, which makes it hold about 100 megabytes of memory on top of what podinfo uses by itself.

Measure what each container uses, and set the requests and limits in the **Deployments** so that:

1.  `scout-overprovisioned` has a CPU request of at least `10m` and at most `200m`, and a memory request of at least `20Mi` and at most `256Mi`.
2.  `scout-overprovisioned` has a memory limit that is at least its memory request and at most `512Mi`.
3.  `scout-underprovisioned` has a memory request that is at least what the container uses and at most three times that.
4.  `scout-underprovisioned` has a memory limit that is at least its memory request, so the kernel no longer kills the container.
5.  Both pods are `Ready`, and the container of `scout-underprovisioned` is not restarted while the grader watches it.

Constraints:

* Do not change the images, the Services or the arguments of the containers.
* Do not remove the memory limits.

The grader reads the Deployments, reads the memory that `scout-underprovisioned` uses from `kubectl top`, and watches the pod for 30 seconds.
