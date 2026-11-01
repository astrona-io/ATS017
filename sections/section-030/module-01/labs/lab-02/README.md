---
estimated_duration: 20m
---

# Slow Down Scale-Down

The HorizontalPodAutoscaler (HPA) for the `scout` Deployment in `starfleet` works, but it uses the default scale-down rules. The team wants a slower, more careful scale-down.

In this lab you add a `behavior.scaleDown` section to the HPA with a stabilization window and a policy, and the grader proves that `scout` keeps its replicas after the load stops.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-030-01-02
```
