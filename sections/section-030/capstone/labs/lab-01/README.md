---
estimated_duration: 40m
---

# Right-Sizing And Autoscaling Capstone

The `scout` Deployment in `starfleet` requests far more CPU and memory than it uses, and nothing adds replicas when the load grows.

In this capstone you measure what `scout` uses, right-size its requests in the Deployment, add a HorizontalPodAutoscaler (HPA) on CPU with a scale-down stabilization window, and prove from a load test that the HPA scales `scout` up and back down.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-capstone-030
```
