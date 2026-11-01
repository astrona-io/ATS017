---
estimated_duration: 15m
---

# Resize A Running Pod In Place

The `scout` pod in `starfleet` needs more CPU, and it must not restart. The Deployment that owns it has a CPU request of `100m` and a CPU limit of `200m`.

In this lab you change the CPU request and limit of the running pod through its `resize` subresource, and you prove that the pod keeps its UID and its container is not restarted.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-030-02-02
```
