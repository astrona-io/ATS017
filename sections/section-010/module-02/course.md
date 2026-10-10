# Place Workloads With Affinity, Taints And Topology Spread

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-010/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Pin pods to labelled nodes with required node affinity and prefer nodes with preferred node affinity
- Reserve a node for one workload with a NoSchedule taint and a matching toleration
- Explain from pod events why a toleration alone does not move a pod onto a tainted node
- Keep replicas apart with pod anti-affinity on kubernetes.io/hostname
- Spread replicas evenly across zones with a topology spread constraint and read the effect of maxSkew and whenUnsatisfiable
- Diagnose a Pending pod caused by an unmatched affinity rule or an untolerated taint from its FailedScheduling message

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Node labels and the well-known labels (kubernetes.io/hostname, topology.kubernetes.io/zone)
- nodeSelector and node affinity, required versus preferred
- Taints and tolerations, and combining them with affinity to dedicate nodes
- Pod anti-affinity and topology spread constraints for high availability

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — Scheduler filter and score steps for taints, node affinity and topology spread -->
<!-- TODO(build): mermaid `flowchart` — Replicas placed across two zones with maxSkew 1 -->

<!-- playground provides: Three-node kind cluster (one control plane, two workers; note the extra memory cost). Workers labelled topology.kubernetes.io/zone=zone-a and zone-b, and one worker labelled `disktype=ssd`. The zone-b worker carries the taint `dedicated=outpost:NoSchedule`. Namespace `starfleet` with `scout` (3 replicas, no placement rules, so the reader sees uneven placement) and `shuttle`. Namespace `outpost` with `probe` without a toleration. No PriorityClasses. -->

<!-- module section-010/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
