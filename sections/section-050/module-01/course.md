# Bound Tenants With ResourceQuota And LimitRange

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Cap a namespace's total CPU and memory requests and limits and object counts with a ResourceQuota
- Read used against hard in kubectl describe resourcequota
- Diagnose a pod or ReplicaSet rejected by a quota from the Forbidden message and the ReplicaSet events
- Set default requests and limits and per-container minimum and maximum with a LimitRange
- Explain why a compute quota requires every new pod to declare requests, and how a LimitRange default solves that

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Why tenants need limits, and the namespace as the tenant boundary
- ResourceQuota for compute, storage and object counts
- LimitRange defaults, minimum, maximum and ratios
- How the two admission steps work together, and finding rejections in ReplicaSet events

## Diagrams planned

<!-- TODO(build): mermaid `sequence` — Pod create passes LimitRange defaulting, then ResourceQuota admission, then is accepted or rejected -->

<!-- playground provides: Single-node kind cluster. Namespaces `starfleet` and `outpost`, each with `scout` and `shuttle`. `outpost` has a `probe` Deployment without resources. No ResourceQuota or LimitRange, so the reader first sees an unbounded tenant and then adds the limits. -->

<!-- module section-050/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
