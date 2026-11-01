---
estimated_duration: 40m
---

# Question

Solve this question on: `terminal`

The Deployment `scout` in the namespace `starfleet` requests `1` CPU and `1Gi` of memory, and it has a memory limit of `1Gi`. The container uses a small part of that. No HorizontalPodAutoscaler (HPA) exists, so nothing adds replicas when the load grows. The `shuttle` Deployment in the same namespace is a client with `curl`.

Measure what `scout` uses, right-size it, and let it scale. Make these changes:

1.  In the Deployment `scout`, set a CPU request of at least `25m` and at most `250m`, and a memory request of at least `24Mi` and at most `256Mi`.
2.  Keep a memory limit that is at least the memory request and at most `512Mi`.
3.  Create an `autoscaling/v2` HPA named `scout` in `starfleet` that scales the Deployment `scout` on CPU of type `Utilization`, with a target between `40` and `80` percent, `minReplicas: 1` and a `maxReplicas` between `3` and `6`.
4.  Give the HPA `behavior.scaleDown.stabilizationWindowSeconds` between `30` and `90`.
5.  Prove it: under a steady load from `shuttle`, the HPA adds at least one replica. After the load ends, the replicas return to `1`.

Constraints:

* Do not change the image or the Service.
* Do not remove the memory limit.

The grader reads the Deployment and the HPA, starts a load of `POST` requests from `shuttle`, waits for the HPA to add a replica, stops the load, and waits up to about five minutes for the replicas to return to `1`. The whole check takes about seven minutes.
