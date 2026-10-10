# Right-Size Workloads From Measured Usage

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Compare a container's requests with its measured usage from kubectl top and find over- and under-provisioned workloads
- Query usage over time with PromQL (container_cpu_usage_seconds_total, container_memory_working_set_bytes) and derive a request from a high percentile
- Resize a running pod's CPU and memory in place with kubectl patch --subresource resize and read status.containerStatuses[].resources
- Set resizePolicy so a memory change restarts the container while a CPU change does not, and read the pod's resize conditions
- Apply the new requests to the Deployment template, and explain why an HPA on CPU and manual CPU right-sizing must not fight each other

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- What right-sizing is, and why requests drive scheduling, autoscaling and cost
- Measuring usage now with kubectl top, and over time with Prometheus queries
- Choosing requests and limits from usage percentiles and headroom
- In-place pod resize in Kubernetes 1.35 and resizePolicy
- Making the change permanent in the workload template, and right-sizing next to an HPA

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — Usage from the kubelet through metrics-server and Prometheus to a new request, applied in place or through the Deployment -->
<!-- TODO(build): mermaid `sequence` — kubectl patch --subresource resize, API server, kubelet, container runtime cgroup update, status updated -->

<!-- playground provides: Single-node kind cluster with metrics-server (astrona addon) and a small Prometheus that scrapes the kubelet's cAdvisor metrics (plumbing for the queries, not a monitoring course). Namespace `starfleet` with `scout-overprovisioned` (CPU and memory requests far above usage) and `scout-underprovisioned` (memory request below usage, Burstable), each under steady load from `shuttle` so usage data exists within a few minutes. No HPA. In-place pod resize is available in Kubernetes 1.35 (verify state and kubectl syntax). -->

<!-- module section-030/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
