---
estimated_duration: 30m
---

# Question

Solve this question on: `terminal`

The namespace `starfleet` runs `scout`, `probe` and `shuttle`. The namespace `outpost` runs `probe` and `archive`. OpenCost runs in the namespace `opencost` and has already collected data.

Every Deployment carries the pod label `team` except `archive` in the namespace `outpost`. The team `operations` owns `archive`. The finance team wants the cost of each team, and it wants the cost of `archive` to appear under `operations` from now on.

A fixed time window is stored in the ConfigMap `report-window` in the namespace `default`. Its key `window` holds two Unix timestamps, in seconds, separated by a comma. The window fixes the start and end of the measurement. Late samples can still change its costs; compare the same window after collection settles.

1.  Ask OpenCost for the cost of each team in that window. Group by the label `team`, and look only at the namespaces `starfleet` and `outpost`.
2.  Create the ConfigMap `team-cost-report` in the namespace `default` with these keys:
    * `window`: exactly the value of the key `window` in `report-window`.
    * `navigation`: the `totalCost` of the team `navigation`, in dollars.
    * `research`: the `totalCost` of the team `research`, in dollars.
    * `unallocated`: the `totalCost` of the bucket that OpenCost uses for cost without a `team` label.
3.  Make OpenCost attribute the cost of `archive` to the team `operations`.

Constraints:

* Store only the number in each cost key, for example `0.0012`, with no dollar sign and no text.
* Do not change the requests or limits of any workload, and do not delete the ConfigMap `report-window`.
* Do not delete the pods by hand to apply the label. Change the Deployment.

The grader accepts a cost within 15 percent of the answer that OpenCost returns for the stored window. It also asks the live OpenCost API for the current `archive` pod. OpenCost needs about 5 minutes after a pod starts before it lists the pod under its team, so the grader retries for up to 8 minutes.
