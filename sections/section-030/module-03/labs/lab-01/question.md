# Question

Solve this question on: `terminal`

## Scenario

The `starfleet` team needs bounded CPU and memory requests for Deployment `scout` and StatefulSet `probe`. Both already run one podinfo container. Vertical Pod Autoscaler (VPA) components and usage metrics are installed, but there are no VPA objects. Apply recommendations only during Pod creation; the team must control replacement.

## Tasks

1. **Create bounded policies.** Create `autoscaling.k8s.io/v1` VerticalPodAutoscalers named `probe` and `scout` in `starfleet`. Set `targetRef.apiVersion: apps/v1`, the matching controller kind (`StatefulSet` for `probe`, `Deployment` for `scout`) and its name. Use `updatePolicy.updateMode: Initial` on both. For each matching container, set `controlledResources: [cpu, memory]`, `controlledValues: RequestsOnly`, minimum CPU `50m` and memory `64Mi`, and maximum CPU `300m` and memory `256Mi`. Obtain a nonempty bounded `status.recommendation` for both containers. Do not add an HPA.
2. **Apply at creation.** Replace both original Pods after recommendations are available. Keep one Ready Pod per workload. Each replacement must have a new UID, bounded CPU and memory requests applied by VPA admission, and running container requests that match the Pod requests. Leave both workload templates at CPU request `500m` and memory request `512Mi`.

Keep the original images, application commands, arguments, HTTP readiness probes and container names. Keep CPU limits at `1` and memory limits at `1Gi` for both application workloads. Use only the two named VPA objects in `starfleet`, with one policy for each named application container, automatic container scaling enabled and no startup boost.
