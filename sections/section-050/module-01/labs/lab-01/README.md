---
estimated_duration: 20m
---

# Fit A Deployment Inside A ResourceQuota

The `probe` Deployment in the namespace `outpost` should run four replicas, but only two pods exist. A ResourceQuota in the namespace refuses the other two.

In this lab you read the rejection, find which quota line is full, and change the Deployment so that all four replicas run inside the quota.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-050/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-050-01-01
```
