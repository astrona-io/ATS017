---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

The `scout` Deployment in the namespace `starfleet` keeps restarting. It starts podinfo with `--stress-memory=100`, which allocates about 100 MB on purpose. The `shuttle` Deployment in the same namespace is a client with `curl`.

Find out why the `scout` container restarts, then fix the resources of the `scout` container so that:

1.  The container is no longer killed. The pod stays `Ready` with no restarts.
2.  The memory **limit** is between `128Mi` and `256Mi`.
3.  The memory **request** is lower than the limit, so the pod has the `Burstable` QoS class.
4.  A request from `shuttle` to `http://scout:9898/healthz` returns HTTP `200`.

Constraints:

* Keep `--stress-memory=100` in the container command. The load is part of the test.
* Do not change the image or the Service.

The grader checks the Deployment, waits 40 seconds to see that the new pod does not restart, reads the pod's QoS class, and sends the request from `shuttle`.
