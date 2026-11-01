---
estimated_duration: 20m
---

# Fix The Unknown HPA Target

The HorizontalPodAutoscaler (HPA) for the `scout` Deployment in `starfleet` shows `<unknown>` as its CPU target. It never adds a replica, however much load `scout` gets.

In this lab you find the reason in the HPA conditions and events, fix it, and prove that the HPA now reads the target and scales `scout` up under load.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-030-01-01
```
