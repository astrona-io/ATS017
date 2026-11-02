---
estimated_duration: 25m
---

# Require Resources With A Kyverno Policy

The namespace `outpost` runs a `probe` Deployment whose pod declares no resources. Nothing stops the next pod from doing the same.

In this lab you write a Kyverno `ClusterPolicy` that denies new pods in `outpost` unless every container declares CPU and memory requests and a memory limit.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-050/module-03/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-050-03-01
```
