---
estimated_duration: 15m
---

# Fix The Pending Claim

The `scout` Deployment in `starfleet` needs storage that survives pod replacement. Its pod never starts, because its PersistentVolumeClaim asks for an access mode that the storage cannot provide.

In this lab you read the claim's events, replace the claim with a supported access mode, and prove that a file survives when the pod is replaced.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-03/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-020-03
```
