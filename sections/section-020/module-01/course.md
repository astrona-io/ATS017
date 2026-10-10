# Route Traffic With The Gateway API

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Name the roles of GatewayClass, Gateway and HTTPRoute and which team owns each
- Create a Gateway listener and attach an HTTPRoute to it with parentRefs
- Route requests by path and by header to two backend Services
- Split traffic between two backends with backendRefs weights
- Diagnose a route that does not attach from its status.parents conditions (Accepted, ResolvedRefs)
- Allow a route from another namespace with allowedRoutes and a ReferenceGrant where needed

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Why the Gateway API replaces Ingress, and the role-oriented resource model
- GatewayClass and the controller (Envoy Gateway) that implements it
- Gateway listeners and HTTPRoute matches, filters and backendRefs
- Reading route and gateway status conditions to find attachment errors
- Cross-namespace routing with allowedRoutes and ReferenceGrant

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — GatewayClass to Gateway to HTTPRoute to Services, with owning roles -->
<!-- TODO(build): mermaid `sequence` — Request from shuttle through the Envoy Gateway proxy to the matched backend -->

<!-- playground provides: Single-node kind cluster with Gateway API standard CRDs and Envoy Gateway installed (GatewayClass `eg`). Namespace `starfleet` with `bridge` (nginx), `scout` and `probe` Services and `shuttle`. Namespace `outpost` with its own `probe`. No Gateway or HTTPRoute yet. Requests are sent from `shuttle` to the Gateway's in-cluster Service address, or through kubectl port-forward, because kind has no load balancer. -->

<!-- module section-020/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
