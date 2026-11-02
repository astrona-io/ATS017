---
estimated_duration: 20m
---

# Make Room With A PriorityClass

The `scout-critical` Deployment in the namespace `starfleet` cannot run: the node is full because the `probe` pods in `outpost` request almost all the free CPU.

In this lab you create a PriorityClass and give it to `scout-critical`, so the scheduler evicts a `probe` pod to make room.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-050/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-050-02-01
```
