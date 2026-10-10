# Read Cost Allocation With OpenCost

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Name the data OpenCost needs (Prometheus metrics, node prices) and where each comes from on a cluster without cloud billing
- Query cost allocation by namespace and by controller with the OpenCost API and the kubectl cost style output
- Read the CPU, memory and storage parts of a workload's cost and the efficiency figure
- Explain how OpenCost allocates cost from the larger of requests and usage

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- What cost allocation is, and how OpenCost computes it from requests, usage and prices
- Installing OpenCost with Prometheus and the default on-premises price list
- Querying the allocation API by window and aggregate, and the user interface
- Reading cost efficiency

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — Prometheus metrics and the price list flowing into OpenCost allocation by namespace and workload -->

<!-- playground provides: Single-node kind cluster with metrics-server, a small Prometheus (prometheus-community/prometheus chart) and OpenCost 1.121.3 with its default on-premises price list. Namespaces `starfleet` (`scout`, `probe`, `shuttle` with load) and `outpost` (`probe`), running long enough before the reader arrives for allocation data to be non-zero. The OpenCost UI is reachable through kubectl port-forward. -->

<!-- module section-040/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
