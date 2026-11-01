---
estimated_duration: 15m
---

# Keep The Volume After Claim Deletion

The `probe-data` claim in `starfleet` holds a file on a volume with the `Delete` reclaim policy. If someone deletes the claim, the volume and the file are gone.

In this lab you change the policy on the existing volume without touching the claim or the pod, and make `standard-retain` the default StorageClass.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-03/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-03/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-020-03-02
```
