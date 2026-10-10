# Share Capacity With PriorityClasses And Quota Scopes

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Create PriorityClasses and assign them to pods with priorityClassName
- Observe a higher-priority pod preempt lower-priority pods on a full node and read the Preempted events
- Prevent preemption by a class with preemptionPolicy Never
- Limit how much of a namespace's quota high-priority pods may use with a PriorityClass scopeSelector
- Count only BestEffort or Terminating pods with quota scopes

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Pod priority and the scheduler's preemption step
- PriorityClass fields, globalDefault and the system classes
- Quota scopes and scopeSelector on PriorityClass
- Designing a fair priority scheme for tenants

## Diagrams planned

<!-- TODO(build): mermaid `sequence` — High-priority pod cannot fit, scheduler picks victims, evicts them, binds the pending pod -->

<!-- playground provides: Three-node kind cluster (one control plane, two workers; note the extra memory cost). Namespaces `starfleet` and `outpost`. `outpost` runs `probe` replicas with large requests that fill the workers' allocatable CPU, so a new pod cannot fit. A `scout-critical` Deployment manifest is ready to apply. No PriorityClasses except the built-in system classes, and no ResourceQuota. -->

<!-- module section-050/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
