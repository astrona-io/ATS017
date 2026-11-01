# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a taint on a node repels pods, and a toleration on a pod allows it onto the tainted node but does not pull it there.
- Know that the scheduler writes the reason a pod is `Pending` into the pod's events (`FailedScheduling`).

The cluster is a `kind` cluster running Kubernetes 1.35 with one control plane and two workers. One worker has the label `topology.kubernetes.io/zone=zone-a`. The other has `topology.kubernetes.io/zone=zone-b` and the taint `dedicated=outpost:NoSchedule`.
