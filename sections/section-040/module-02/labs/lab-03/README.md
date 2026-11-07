---
estimated_duration: 25m
---

# Scale Replicas By Cost

The namespace `starfleet` runs four Deployments with different replica counts and requests. OpenCost and a small Prometheus already run in the cluster and have collected cost data for a closed window.

In this lab you rank the Deployments by cost from the OpenCost API, record the most and the least expensive one in a ConfigMap, scale the most expensive one down to one replica and the least expensive one up to three. Requests stay as they are.

## Launching the Lab

Run this command to start the cluster. The start-up takes about 10 minutes, because the script waits until OpenCost has collected enough data:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-02/labs/lab-03
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-02/labs/lab-03
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-040-02-03
```
