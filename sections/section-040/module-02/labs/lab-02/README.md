---
estimated_duration: 25m
---

# Cut Idle Cost By Right-Sizing

The namespace `starfleet` runs four Deployments. One of them requests far more CPU and memory than it uses, so it pays for capacity that no workload can use. OpenCost and a small Prometheus already run in the cluster and have collected cost data.

In this lab you find that Deployment from the OpenCost data and lower its requests so that they fit its usage. The pod must keep running and answering.

## Launching the Lab

Run this command to start the cluster. The start-up takes about 10 minutes, because the script waits until OpenCost has collected enough data:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-040-02-02
```
