---
estimated_duration: 30m
---

# Question

Solve this question on: `terminal`

The cluster has two worker nodes. One has the labels `topology.kubernetes.io/zone=zone-a` and `disktype=ssd`. The other has `topology.kubernetes.io/zone=zone-b`.

Two Deployments are wrong:

* `scout` in the namespace `starfleet` has 4 replicas, no requests or limits, and a `nodeSelector` that puts every pod in `zone-a`.
* `probe` in the namespace `outpost` has 2 replicas and a required node affinity for `disktype=nvme`. Its pods stay `Pending`.

Fix them so that:

1.  Every `scout` pod has the `Guaranteed` QoS class. Use CPU `100m` and memory `64Mi` for both request and limit.
2.  The 4 `scout` pods are spread evenly across the two zones, 2 in each, by a topology spread constraint on `topology.kubernetes.io/zone` with `maxSkew: 1`. Remove the `nodeSelector`.
3.  Both `probe` pods run on the node with `disktype=ssd`, through the required node affinity.
4.  The `shuttle` Deployment in `starfleet` gets HTTP `200` from `http://scout:9898/healthz` and from `http://probe.outpost:8080/status/200`.

Constraints:

* The scheduler applies a topology spread constraint only when it places a pod. Check the real spread with `kubectl get pods -o wide` when you finish.
* Do not change node labels.
* Keep the required node affinity on `probe`. Do not replace it with a `nodeSelector`.

The grader reads the QoS class and node of every pod, the topology spread constraint and the affinity, and sends requests from `shuttle`.
