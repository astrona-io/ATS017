---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

The HorizontalPodAutoscaler `scout` in the namespace `starfleet` scales the Deployment `scout` on CPU utilisation, with a target of `50` percent, between `1` and `5` replicas. It has no `behavior` section. The `shuttle` Deployment in the same namespace is a client with `curl`.

Change the HPA `scout` so that it scales down slowly:

1.  `behavior.scaleDown.stabilizationWindowSeconds` is between `120` and `600`.
2.  `behavior.scaleDown.policies` has a policy of type `Pods` with `value: 1`, or a policy of type `Percent` with a `value` of `25` or less. Each policy has a `periodSeconds` of at least `30`.
3.  The scale-down is not disabled: `selectPolicy` is not `Disabled`.
4.  After a load from `shuttle` ends, the HPA does not remove replicas within the next 45 seconds.

Constraints:

* Keep the metric (CPU `Utilization` of `50`), `minReplicas: 1` and `maxReplicas: 5`.
* Do not delete the HPA and do not change the Deployment.
* Do not slow down scale-up: leave `behavior.scaleUp` out or keep its `stabilizationWindowSeconds` at `0`.

The grader reads the HPA spec, starts a load from `shuttle` until `scout` has three or more replicas, stops the load, and checks the replica count 45 seconds later.
