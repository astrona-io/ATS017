# Question

Solve this question on: `terminal`

## Scenario

This is the Section 030 capstone: one integrated autoscaling task, no step-by-step guidance. The `starfleet` team wants StatefulSet `probe` sized at Pod creation and Deployment `scout` scaled horizontally. Both start with one Pod requesting `500m` CPU and `512Mi` memory. Vertical Pod Autoscaler (VPA) components, metrics-server and client Deployment `shuttle` are installed. No autoscaler objects exist yet. Allow 35 minutes.

## Tasks

1. **Separate resource ownership.** Create VPA objects named `probe` and `scout` in `starfleet`, with `targetRef.apiVersion: apps/v1` and their matching controller kinds and names. Use `Initial` for StatefulSet `probe` and `Off` for Deployment `scout`. For each matching application container, control `[cpu, memory]`, use `RequestsOnly`, and bound recommendations between CPU `50m` and memory `64Mi`, and CPU `300m` and memory `256Mi`. Obtain recommendations for both. Do not put an HPA on `probe`.
2. **Apply the StatefulSet recommendation.** Replace the original `probe-0` after its recommendation is ready. Keep one Ready `probe` Pod with a new UID, bounded CPU and memory requests applied by VPA admission, and matching running container requests. Leave its template requests at `500m` CPU and `512Mi` memory.
3. **Right-size the Deployment.** Inspect live container usage and the `scout` recommendation. Reduce the `scout` template requests to the team's budget of CPU `100m` and memory `256Mi`. Complete the rollout and keep its Pods Ready with those requests. Their measured memory usage must fit within `256Mi`. VPA must stay `Off`, so these requests come from the template.
4. **Scale on CPU.** Create an `autoscaling/v2` HorizontalPodAutoscaler (HPA) named `scout` in `starfleet`, targeting `apps/v1` Deployment `scout`. Set `minReplicas: 1`, `maxReplicas: 3`, only a CPU `Resource` metric with `target.type: Utilization` and `averageUtilization: 60`, and `behavior.scaleDown.stabilizationWindowSeconds: 60`. Generate requests from `shuttle` to the `scout` Service. Under load, the HPA must report `ScalingActive: True`, CPU utilisation above 60 percent, and at least two Ready `scout` replicas. Keep `shuttle` available for load generation.

Keep the original images, application commands, arguments, HTTP readiness probes and container names. Keep CPU limits at `1` and memory limits at `1Gi` for both application workloads. Use only the two named VPA objects in `starfleet`, with one policy for each named application container, automatic container scaling enabled and no startup boost.
