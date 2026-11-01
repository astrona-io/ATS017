---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

Two teams share this cluster. The namespace `starfleet` runs `scout`, `probe` and `shuttle`. The namespace `outpost` runs `probe`, which mounts a 20Gi PersistentVolumeClaim named `archive`. OpenCost runs in the namespace `opencost` and has already collected data.

A fixed time window is stored in the ConfigMap `report-window` in the namespace `default`. Its key `window` holds two Unix timestamps, in seconds, separated by a comma. The window is closed, so OpenCost returns the same costs for it every time.

Ask OpenCost for the cost of each namespace in that window, and store the result in a new ConfigMap:

1.  Create the ConfigMap `namespace-cost-report` in the namespace `default`.
2.  Give it the key `window`, with exactly the value of the key `window` in `report-window`.
3.  Give it the key `starfleet`, with the `totalCost` of the namespace `starfleet` for that window, in dollars.
4.  Give it the key `outpost`, with the `totalCost` of the namespace `outpost` for that window, in dollars.

Constraints:

* Store only the number in each cost key, for example `0.0012`, with no dollar sign and no text.
* Do not change the workloads. Report their cost, do not change it.
* Do not delete the ConfigMap `report-window`.

The grader asks OpenCost for the same window and accepts a value within 15 percent of the answer.
