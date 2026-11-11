---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

The namespace `starfleet` runs four Deployments: `scout`, `relay`, `beacon` and `shuttle`. OpenCost runs in the namespace `opencost` and has already collected data. The finance team wants the cluster to spend less on the Deployment that costs the most, and the platform team wants more replicas of the Deployment that costs the least, because it is cheap to run.

A fixed time window is stored in the ConfigMap `report-window` in the namespace `default`. Its key `window` holds two Unix timestamps, in seconds, separated by a comma. The window fixes the start and end of the measurement. Late samples can still change its costs; compare the same window after collection settles.

1.  Query OpenCost for that window, grouped by namespace and controller, and look only at the namespace `starfleet`. Rank the Deployments by `totalCost`.
2.  Create the ConfigMap `cost-scaling-report` in the namespace `default` with these keys:
    * `window`: exactly the value of the key `window` in `report-window`.
    * `highest`: the name of the Deployment with the highest `totalCost`.
    * `lowest`: the name of the Deployment with the lowest `totalCost`.
3.  Scale the Deployment with the highest `totalCost` down to `1` replica.
4.  Scale the Deployment with the lowest `totalCost` up to `3` replicas.

Constraints:

* Change the replica counts only. Do not change the CPU or memory requests of any Deployment, and do not delete a Deployment.
* Both scaled Deployments must finish their rollout, every replica must be ready, and both must answer HTTP requests on their Service.
* Do not scale the other two Deployments.

The grader reads the ConfigMap and the Deployments, and sends a request from `shuttle` to both Services. It does not call OpenCost, because a change in replicas shows up in OpenCost only after several minutes.
