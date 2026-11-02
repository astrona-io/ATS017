---
estimated_duration: 25m
---

# Default Resources With A LimitRange

The `batch-worker` Deployment in the namespace `outpost` has three replicas, but no pod runs. A ResourceQuota requires every container to declare requests and a memory limit, and the Deployment declares none.

In this lab you add a LimitRange to the namespace so that pods without resources get defaults, and so that no container can ask for more than a fixed maximum.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-050/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-050-01-02
```
