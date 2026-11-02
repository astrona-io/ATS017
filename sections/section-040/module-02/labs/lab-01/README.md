---
estimated_duration: 30m
---

# Attribute Cost To Teams

Two namespaces share a cluster. Every Deployment carries a `team` label except one, `archive` in the namespace `outpost`. OpenCost and a small Prometheus already run in the cluster and have collected cost data.

In this lab you record the cost of each team for a fixed window of time, and you add the missing `team` label so that OpenCost attributes the cost of `archive` to its team.

## Launching the Lab

Run this command to start the cluster. The start-up takes about 10 minutes, because the script waits until OpenCost has collected enough data:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-02/labs/lab-01
```

When you think you have finished, send it for grading. The grader waits up to 8 minutes for OpenCost to show the new pod under its team:

```bash
astrona submit -c sections/section-040/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-040-02-01
```
