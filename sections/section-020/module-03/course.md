# Provision Storage With StorageClasses

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-03/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Read a StorageClass's provisioner, reclaimPolicy, volumeBindingMode and allowVolumeExpansion fields
- Create a PersistentVolumeClaim and explain why it stays Pending under WaitForFirstConsumer until a pod uses it
- Mount a claim in a pod and prove that data survives a pod restart
- Choose an access mode (ReadWriteOnce, ReadOnlyMany, ReadWriteMany, ReadWriteOncePod) for a workload
- Predict what happens to the volume when a claim is deleted under Delete and Retain reclaim policies
- Set the default StorageClass with the is-default-class annotation

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Volumes, PersistentVolumes and PersistentVolumeClaims, and who creates each
- StorageClasses and dynamic provisioning, with kind's local-path provisioner as the example
- Binding modes, access modes and reclaim policies
- StatefulSet volumeClaimTemplates for one claim per replica

## Diagrams planned

<!-- TODO(build): mermaid `sequence` — PVC created, pod scheduled, provisioner creates PV, PV binds to PVC, kubelet mounts it -->
<!-- TODO(build): mermaid `state` — PVC and PV lifecycle (Pending, Bound, Released) under each reclaim policy -->

<!-- playground provides: Single-node kind cluster with kind's default StorageClass `standard` (rancher.io/local-path, WaitForFirstConsumer). A second StorageClass `standard-retain` with reclaimPolicy Retain. Namespace `starfleet` with `shuttle` and no PersistentVolumeClaims. A `probe` StatefulSet manifest with volumeClaimTemplates is ready to apply. -->

<!-- module section-020/module-03 (Module 3) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
