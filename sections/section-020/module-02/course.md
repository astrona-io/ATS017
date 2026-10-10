# Isolate Traffic With NetworkPolicy

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Apply a default-deny ingress and egress policy to a namespace and prove that requests now time out
- Allow one flow between two workloads with podSelector and ports
- Allow traffic from another namespace with namespaceSelector, and tell apart AND versus OR selector combinations
- Restore DNS for selected pods with an egress rule to kube-dns on port 53 UDP and TCP
- Diagnose which policy blocks a request by listing the policies that select a pod

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- How NetworkPolicy works, the CNI that enforces it, and why selecting a pod makes it default-deny
- Default-deny policies and the DNS egress rule every namespace needs
- Ingress and egress rules with podSelector, namespaceSelector and ipBlock
- The from-list pitfall, one item with two selectors versus two items

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — Allowed and denied flows between shuttle, scout and probe across starfleet and outpost -->

<!-- playground provides: Single-node kind cluster (kind's default CNI kindnet enforces NetworkPolicy since kind v0.24.0). Namespaces `starfleet` (`scout`, `probe`, `shuttle`) and `outpost` (`probe`, a second `shuttle`), each namespace labelled with kubernetes.io/metadata.name. No NetworkPolicy at all, so every request succeeds at the start and the reader sees each policy remove traffic. -->

<!-- module section-020/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
