# Summary

Two small maps on every container decide where a pod runs, how much it may use, and which pods a node gives up first. This module followed them from the scheduler to the kernel.

## What you learned

`resources.requests` is what the scheduler reserves for a container, and `resources.limits` is the most it may use. CPU is counted in cores and millicores (`200m`), memory in bytes with binary units (`128Mi`). The scheduler reads requests once, before the pod starts, and compares them only with each node's allocatable capacity, never with real usage. The kubelet writes the limits into the container's control group, and from then on the Linux kernel enforces them. A container with only limits gets the same values as requests.

The two resources fail differently at their limit. CPU is compressible: the kernel throttles the container, its usage stays flat at the limit, nothing restarts, and `nr_throttled` in `cpu.stat` grows. Memory is incompressible: the out-of-memory killer ends the process, the container restarts, and `Last State` shows `Reason: OOMKilled` with exit code `137`, followed by `CrashLoopBackOff`.

Every pod gets a QoS class in `status.qosClass`. `Guaranteed` means CPU and memory limits equal the requests in every container, `BestEffort` means no resources at all, and everything else is `Burstable`. Under node memory pressure the kubelet evicts pods whose usage is above their memory request first, so `BestEffort` pods go first and `Guaranteed` pods last.

`kubectl describe node` shows capacity, allocatable, the requests of each pod and the total reserved. When no node has room for a pod's requests, the pod stays `Pending` and a `FailedScheduling` event names the reason per node, such as `Insufficient memory`. `kubectl explain pod.spec.containers.resources` prints the field reference and the address of the resource management page on `kubernetes.io`. The key facts to remember are these:

- Requests place pods; limits cap them while they run.
- CPU over its limit is throttled; memory over its limit is `OOMKilled`.
- The memory request is the main input to eviction order.
- A `Pending` pod's reason is in its `FailedScheduling` event, not on the Deployment.

<!-- astrona:playground:destroy -->
