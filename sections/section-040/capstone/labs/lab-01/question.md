---
estimated_duration: 45m
---

# Question

Solve this question on: `terminal`

The finance team of the Starfleet wants a cost report per team. The namespace `starfleet` runs `scout`, `probe`, `analytics` and `shuttle`. The namespace `outpost` runs `archive`. OpenCost runs in the namespace `opencost` and has already collected data.

Three teams own the Deployments:

* `navigation` owns `scout` and `shuttle`.
* `operations` owns `probe` and `archive`.
* `science` owns `analytics`.

Only `scout` and `shuttle` carry the pod label `team` today. A fixed time window is stored in the ConfigMap `report-window` in the namespace `default`. Its key `window` holds two Unix timestamps, in seconds, separated by a comma. The window is closed, so OpenCost returns the same costs for it every time. The labels did not exist in that window, so you cannot group it by the label.

1.  Ask OpenCost for the cost of each Deployment in that window. Look only at the namespaces `starfleet` and `outpost`.
2.  Create the ConfigMap `cost-report` in the namespace `default` with these keys:
    * `window`: exactly the value of the key `window` in `report-window`.
    * `navigation`, `operations` and `science`: the total cost of the Deployments that team owns in that window, in dollars (the sum of their `totalCost` values).
    * `least-efficient`: the name of the Deployment with the lowest `totalEfficiency` in that window.
3.  Add the `team` label to the pods of every Deployment that has none, so OpenCost attributes their cost to the right team from now on.
4.  Right-size the Deployment you named in `least-efficient`. It uses far less than it requests. Set requests that fit its usage, and keep it running.

Constraints:

* Store only the number in each cost key, for example `0.0012`, with no dollar sign and no text.
* Change only the requests of the least efficient Deployment. Do not change the requests of any other workload, and do not delete the ConfigMap `report-window`.
* Do not delete pods by hand to apply a label. Change the Deployment.

The grader accepts a cost within 15 percent of the answer that OpenCost returns for the stored window. It checks that `shuttle` still gets an HTTP 200 answer from the right-sized Deployment.
