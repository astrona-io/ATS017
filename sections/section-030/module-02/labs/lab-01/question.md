# Question

Solve this question on: `terminal`

Deployment `scout-overprovisioned` in `starfleet` requests 1000m CPU and 1Gi memory despite a small steady load. The `shuttle` client sends a steady request each second. Metrics Server supplies current usage; this independent lab does not install Prometheus.

## Tasks

1. Inspect the Deployment resources, Pod state and usage with `kubectl top`. For a restarting Pod, inspect its termination reason and arguments before choosing an initial memory increase.
2. Set requests and limits on the Deployment using measured usage and headroom. Use a CPU request from 10m through 200m, a memory request from 20Mi through 256Mi and a memory limit no higher than 512Mi. Keep the memory request at or above observed usage and the memory limit at or above the request.
3. Wait for the rollout, measure the new Pod and confirm it remains Ready without restarting. The grader observes the same Pod for 30 seconds.

## Constraints

- Preserve the Deployment and Service identities, replicas, image, arguments, probes and selectors. Change only resource requests and limits.
- Keep the memory limit. Do not remove the workload or its stress argument.

Learner work: about 15 minutes. Cluster startup, metric collection and the 30-second stability observation take additional time.
