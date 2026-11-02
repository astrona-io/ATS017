# Summary

A request should be the measured usage plus headroom, and the Deployment template must hold the final value. This module followed that sentence from the first measurement to the last template edit.

## What you learned

Right-sizing starts with two numbers for each container: what it requests and what it uses. The scheduler reserves the request, and the HPA divides the usage by it. `kubectl top` shows the latest usage from metrics-server, and `kubectl describe node` shows the requests already handed out. A single reading is not enough, because a workload can peak at another time. Prometheus scrapes the kubelet's cAdvisor endpoint and stores the history. The metrics `container_memory_working_set_bytes` and `rate(container_cpu_usage_seconds_total[1m])` give memory in bytes and CPU in cores, and a subquery such as `max_over_time(...[5m:15s])` or `quantile_over_time(0.95, ...)` turns the history into one number.

A request comes from that number plus headroom. This course sizes the memory request at the peak plus about 25 percent, rounded up, and sets the memory limit equal to it, because a container over its memory limit is killed with `OOMKilled`. It sizes the CPU request at the 95th percentile or the peak plus about 30 percent, with a small floor, and sets no CPU limit, because a CPU limit only throttles. A request far above usage wastes node capacity, and a memory request below usage makes the pod the first to be evicted under pressure.

In-place pod resize changes a running container's requests and limits without recreating the pod. It is on by default in Kubernetes 1.35. The change goes through `kubectl patch --subresource resize`, and a plain patch of a pod is rejected. The pod records the result in `spec.containers[*].resources`, in `status.containerStatuses[*].resources` and in `allocatedResources`, and the kubelet writes `ResizeStarted` and `ResizeCompleted` events. The field `resizePolicy` decides for each resource whether the kubelet changes it in place (`NotRequired`) or restarts the container (`RestartContainer`). A resize that the node cannot fit gets the condition `PodResizePending` with the reason `Infeasible`. A memory limit below the current usage leaves `PodResizeInProgress` and a `ResizeError` event. A resize may not change the QoS class of the pod.

An in-place resize changes one pod and not its Deployment. The next pod starts from the template, so the final values must be written there with `kubectl set resources` or an edited manifest. The same numbers decide how an HPA on CPU reads the workload, so the CPU request is right-sized first, and pods under an HPA are changed through the template and not one by one. The key facts to remember are these:

- Measure usage over a period that includes the peak, not from one `kubectl top` reading.
- Memory limit at or above the peak, no CPU limit, and headroom on the request.
- Resize a pod with `kubectl patch --subresource resize`, and prove it from `status.containerStatuses[*].resources`.
- `resizePolicy` sets which resource restarts the container.
- The Deployment template keeps the final values.

<!-- astrona:playground:destroy -->
