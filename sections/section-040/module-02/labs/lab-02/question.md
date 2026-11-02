---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

The namespace `starfleet` runs four Deployments: `scout`, `scout-overprovisioned`, `shuttle` and `crunch`. OpenCost runs in the namespace `opencost` and has already collected data. The finance team asks the team `science` to lower the cost of its workloads without hurting them.

A fixed time window is stored in the ConfigMap `report-window` in the namespace `default`. Its key `window` holds two Unix timestamps, in seconds, separated by a comma.

1.  Query OpenCost for the window, grouped by namespace and controller, and compare `totalEfficiency` with the real usage from `kubectl top pods`.
2.  Find the Deployment of the team `science` that requests far more than it uses.
3.  Lower its CPU and memory requests so that they fit its usage with a margin. Change the Deployment, so the new requests survive a restart.

Constraints:

* The pod must be `Running` and must answer HTTP requests on its Service. Do not scale the Deployment to zero and do not delete it.
* Request at least `10m` CPU and `40Mi` memory, and at most `250m` CPU and `384Mi` memory. The workload uses about `2m` CPU and `25Mi` memory.
* Do not change the other Deployments. One of them uses what it requests, so lowering it would only hurt it.

The grader reads the requests of the Deployment and of its running pod, and sends a request from `shuttle` to the Service. It does not call OpenCost, because OpenCost shows a change in requests only after several minutes.
