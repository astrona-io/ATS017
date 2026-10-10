# Scale Workloads With The HorizontalPodAutoscaler

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Create an autoscaling/v2 HPA with a CPU utilisation target and minReplicas and maxReplicas
- Calculate the desired replica count from current and target utilisation with the HPA formula
- Generate load from shuttle and watch the HPA scale up and back down with kubectl get hpa --watch
- Diagnose an HPA that shows unknown targets because the pods have no CPU requests or metrics-server is missing
- Slow down scale-down with behavior.scaleDown stabilizationWindowSeconds and policies

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- The Metrics API, metrics-server and kubectl top
- The HPA control loop and its replica formula
- Writing an autoscaling/v2 HPA with resource metrics
- Reading HPA status, conditions and events, and fixing unknown targets
- Scaling behavior and stabilization windows

## Diagrams planned

<!-- TODO(build): mermaid `sequence` — metrics-server collects from kubelets, HPA controller reads Metrics API, updates Deployment replicas -->
<!-- TODO(build): mermaid `flowchart` — HPA decision from current utilisation, target and behavior limits to the new replica count -->

<!-- playground provides: Single-node kind cluster with metrics-server (--kubelet-insecure-tls). Namespace `starfleet` with `scout` (1 replica, CPU request 100m) and `scout-norequests` (no resources set, the deliberate variation that gives an HPA unknown targets), plus `shuttle` with a load loop script that calls podinfo's CPU endpoint. No HPA yet. -->

<!-- module section-030/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
