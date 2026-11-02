---
estimated_duration: 45m
---

# Cost Visibility Capstone

Two namespaces share a cluster, and three teams own the workloads. Only some workloads carry a `team` label. OpenCost and a small Prometheus already run in the cluster and have collected cost data.

In this capstone you label every workload with its team, report the cost of each team for a fixed window of time, find the least efficient workload and right-size it.

## Launching the Lab

Run this command to start the cluster. The start-up takes about 10 minutes, because the script waits until OpenCost has collected enough data:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-capstone-040
```
