# Attribute Cost By Label And Find Idle Spend

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Aggregate cost by a team label and by namespace in the OpenCost API
- Find workloads with low cost efficiency and name the requests to change
- Read idle cost and explain how it shrinks when requests fit the nodes better
- Add cost-attribution labels to workloads and confirm OpenCost picks them up

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Labels as the unit of showback and chargeback
- Aggregating by label, namespace and controller
- Idle cost, shared cost, and what to change to reduce each

<!-- playground provides: Same base as the OpenCost reading module: kind, metrics-server, Prometheus, OpenCost with the default price list. `starfleet` workloads carry a `team` label; one `outpost` Deployment has no `team` label (the deliberate gap), and `scout-overprovisioned` requests far more than it uses, so low efficiency and idle cost are visible. -->

<!-- module section-040/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
