---
estimated_duration: 20m
---

# Limit High-Priority Pods With A Quota Scope

The namespace `outpost` runs two `beacon` pods that use the PriorityClass `platform-high`. Nothing stops the tenant from creating more pods of that class, or pods without any resources.

In this lab you add scoped ResourceQuotas to `outpost` so that the namespace keeps at most two `platform-high` pods and accepts no pod without resources.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-050/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-050-02-02
```
