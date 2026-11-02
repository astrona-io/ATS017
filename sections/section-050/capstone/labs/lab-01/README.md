---
estimated_duration: 45m
---

# Multi-Tenancy Capstone

Two namespaces share one node. The `outpost` namespace uses almost all the free CPU and has a ResourceQuota. The `starfleet` namespace has a critical Deployment that cannot start, and `outpost` has a Deployment that the quota rejects.

In this capstone you create a PriorityClass so the critical pod preempts a lower-priority pod, set defaults with a LimitRange so the rejected pods run, and use a scoped ResourceQuota to keep that PriorityClass out of `outpost`.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-050/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-capstone-050
```
