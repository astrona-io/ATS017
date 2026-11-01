---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

The HorizontalPodAutoscaler `scout` in the namespace `starfleet` scales the Deployment `scout` on CPU utilisation, with a target of `50` percent. `kubectl get hpa -n starfleet` shows the target as `<unknown>/50%`, and the replica count never changes. The `shuttle` Deployment in the same namespace is a client with `curl`.

Find out why the HPA cannot read its target, and fix it so that:

1.  The `scout` container has a CPU **request** of at least `50m` and at most `250m`.
2.  The HPA `scout` shows a number for its CPU target, not `<unknown>`, and its `ScalingActive` condition is `True`.
3.  The HPA still scales the Deployment `scout` on CPU of type `Utilization`.
4.  When `shuttle` sends a steady stream of requests to `http://scout/token`, the HPA adds at least one replica to `scout`.

Constraints:

* Do not delete the HPA or change its metric type.
* Do not change the image or the Service.

The grader reads the Deployment and the HPA, waits for the target to resolve, starts a load of `POST` requests from `shuttle`, and waits up to about three minutes for `scout` to have two or more replicas.
