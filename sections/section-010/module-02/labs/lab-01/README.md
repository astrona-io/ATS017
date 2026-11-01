---
estimated_duration: 15m
---

# Run Probe On The Dedicated Node

The `probe` Deployment in `outpost` must run on the worker in `zone-b`. That worker has a taint, and `probe` has no toleration, so its pods stay `Pending`.

In this lab you read the scheduler message and let `probe` onto the tainted node without removing the taint.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-010/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-010-02-01
```
