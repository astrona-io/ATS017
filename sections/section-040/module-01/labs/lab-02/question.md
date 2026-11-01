---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

The namespace `starfleet` runs five Deployments: `scout`, `probe`, `shuttle`, `crunch` and `reports`. The namespace `outpost` runs `probe`. OpenCost runs in the namespace `opencost` and has already collected data.

A fixed time window is stored in the ConfigMap `report-window` in the namespace `default`. Its key `window` holds two Unix timestamps, in seconds, separated by a comma. The window is closed, so OpenCost returns the same values for it every time.

Find the Deployment in the namespace `starfleet` that uses the smallest share of what it requests, and name it in a new ConfigMap:

1.  Query OpenCost for the window, grouped by namespace and controller.
2.  Compare the field `totalEfficiency` of the Deployments in `starfleet`.
3.  Create the ConfigMap `least-efficient` in the namespace `default`, with the key `controller` set to the name of the Deployment with the lowest `totalEfficiency`, for example `scout`.

Constraints:

* Store only the Deployment name.
* Do not change the workloads. Find the workload, do not change it yet.
* Do not delete the ConfigMap `report-window`.

The grader reads the same window from OpenCost and checks that your Deployment has the lowest `totalEfficiency` in `starfleet`.
