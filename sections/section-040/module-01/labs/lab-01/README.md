---
estimated_duration: 25m
---

# Report Cost Per Namespace

Two teams share a cluster. The `starfleet` namespace runs three Deployments, and the `outpost` namespace runs one Deployment with a 20Gi volume. OpenCost and a small Prometheus already run in the cluster and have collected cost data.

In this lab you ask the OpenCost allocation API for the cost of each namespace in a fixed window of time, and you write the two numbers into a ConfigMap.

## Launching the Lab

Run this command to start the cluster. The start-up takes about 10 minutes, because the script waits until OpenCost has collected enough data:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-040-01-01
```
