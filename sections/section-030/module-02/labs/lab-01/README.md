---
estimated_duration: 25m
---

# Right-Size From Measured Usage

Two Deployments in `starfleet` have the wrong requests. `scout-overprovisioned` asks for far more CPU and memory than it uses. `scout-underprovisioned` asks for less memory than it needs, and the kernel kills its container with `OOMKilled`.

In this lab you measure what each container really uses, and you set requests and limits that fit the measured usage with headroom.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-030-02-01
```
