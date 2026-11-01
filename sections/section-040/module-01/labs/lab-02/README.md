---
estimated_duration: 25m
---

# Find The Least Efficient Workload

The namespace `starfleet` runs five Deployments: `scout`, `probe`, `shuttle`, `crunch` and `reports`. The namespace `outpost` runs one more. The team wants to shrink the requests of the one workload that wastes the most of what it reserves. The workload that costs the most is not always that one.

In this lab you read the efficiency of each Deployment from OpenCost for a fixed window of time, and you name the least efficient Deployment in `starfleet` in a ConfigMap.

## Launching the Lab

Run this command to start the cluster. The start-up takes about 10 minutes, because the script waits until OpenCost has collected enough data:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-040-01-02
```
