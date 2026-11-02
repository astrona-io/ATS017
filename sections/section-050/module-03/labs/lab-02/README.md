---
estimated_duration: 30m
---

# Generate Tenant Defaults With Kyverno

Every new tenant namespace needs the same ResourceQuota and LimitRange, and today someone must create them by hand.

In this lab you write a Kyverno `ClusterPolicy` with `generate` rules that create both objects in every namespace that has the label `tenant: "true"`.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-03/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-050/module-03/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-050-03-02
```
