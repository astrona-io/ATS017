---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

Kyverno is installed in the cluster. The namespace `outpost` runs the Deployment `probe`, whose pod declares no resources. The platform team wants every new pod in `outpost` to declare resources.

Create a Kyverno `ClusterPolicy` so that, in the namespace `outpost`:

1.  A pod whose container declares no resources is denied by Kyverno.
2.  A pod whose container declares CPU and memory requests but no memory limit is denied by Kyverno.
3.  A pod whose container declares a CPU request, a memory request and a memory limit is accepted.

Constraints:

* The policy must deny the request (`Enforce`). A policy that only reports is not enough.
* Apply the policy only to the namespace `outpost`. Pods in `starfleet` must stay allowed without resources.
* Do not delete the Deployment `probe`, and do not use a LimitRange to solve this.

The grader creates a pod without resources, a pod without a memory limit and a pod with full resources in `outpost`, and a pod without resources in `starfleet`, and reads the result of each.
