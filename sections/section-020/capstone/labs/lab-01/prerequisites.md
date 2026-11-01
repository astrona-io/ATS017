# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know the Gateway API objects `Gateway` and `HTTPRoute`, and how `parentRefs` and `backendRefs` connect them.
- Know how a default-deny `NetworkPolicy` works for ingress and egress, and why DNS needs its own egress rule.
- Know how a `PersistentVolumeClaim` gets storage from a StorageClass under `WaitForFirstConsumer`.

The cluster is a single-node `kind` cluster running Kubernetes 1.35, with a Gateway API controller and the GatewayClass `eg` installed. The StorageClass `standard-retain` exists. NetworkPolicy is enforced by kind's default network plugin.
