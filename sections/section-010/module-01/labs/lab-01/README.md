---
estimated_duration: 15m
---

# Stop The OOMKilled Scout

The `scout` Deployment in `starfleet` restarts again and again. The kubelet kills its container because the container uses more memory than its limit.

In this lab you find the reason in the pod status and set requests and limits that let `scout` run, with the `Burstable` QoS class.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-010/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-010-01-01
```
