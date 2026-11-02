---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

The Deployment `scout-critical` in the namespace `starfleet` has one replica, but its pod stays `Pending`. The node has too little free CPU, because the Deployment `probe` in the namespace `outpost` runs three pods that request almost all of it. The `scout-critical` pod is more important than `probe`.

Make `scout-critical` run, so that:

1.  A new PriorityClass exists, with a value above `0` and below `1000000000`, that allows preemption.
2.  The Deployment `scout-critical` uses that class, and its pod is `Ready`.
3.  The scheduler placed the pod by preempting a `probe` pod.

Constraints:

* Do not change the CPU request of `scout-critical` (`300m`).
* Do not delete, scale or edit the Deployment `probe`.
* Do not use a system PriorityClass (`system-cluster-critical` or `system-node-critical`).

The grader reads both Deployments, the class and its value, waits for a ready pod, and looks for a `Preempted` event.
