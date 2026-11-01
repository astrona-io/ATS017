# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know how requests and limits decide the QoS class (`Guaranteed` needs every request equal to its limit for CPU and memory).
- Know how a topology spread constraint (`maxSkew`, `topologyKey`, `whenUnsatisfiable`) and required node affinity decide placement.

The cluster is a `kind` cluster running Kubernetes 1.35 with one control plane and two workers. One worker has `topology.kubernetes.io/zone=zone-a` and `disktype=ssd`. The other has `topology.kubernetes.io/zone=zone-b`.
