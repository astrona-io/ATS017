---
estimated_duration: 30m
---

# Compute Placement And Sizing Capstone

This lab combines the section: requests and limits, QoS classes, topology spread constraints and node affinity.

The `scout` Deployment has no resources and runs only on one zone. The `probe` Deployment cannot be scheduled because its node affinity asks for a disk type that no node has. You fix both and prove the result with pod placement and status.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-010/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-capstone-010
```
