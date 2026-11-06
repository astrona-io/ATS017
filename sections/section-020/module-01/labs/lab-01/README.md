---
estimated_duration: 25m
---

# Repair Gateway Route Attachment

Repair two HTTPRoutes in a single-node Kubernetes 1.35 cluster. The Gateway
API addon is the same Envoy implementation used by the section capstone.
Workloads and tools are ready; the learner repairs attachment and routing.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-01/labs/lab-01
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-01/labs/lab-01
astrona destroy ats-017-lab-020-01
```

The four checks read live conditions and send real requests from `shuttle`
through the Gateway. Static authoring checks do not prove runtime success.
