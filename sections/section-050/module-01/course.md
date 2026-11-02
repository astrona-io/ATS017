# Bound Tenants With ResourceQuota And LimitRange

A Kubernetes cluster that several teams share has one weak point: by default, nothing limits how much of it a team can take. One team can create hundreds of pods, or pods that request all the CPU of a node, and every other team feels it. The tool for this is the namespace. A namespace is the boundary of a tenant (one team and its workloads), and two objects put a limit on that boundary.

A **ResourceQuota** is a namespaced object that caps the total amount of compute, storage and objects that all workloads in the namespace may use together. A **LimitRange** is a namespaced object that sets default, minimum and maximum values for each single container or pod in the namespace. The quota limits the namespace as a whole. The LimitRange limits each container and fills in the values a container leaves out.

Keep one sentence in mind for this module: **a compute quota rejects every new pod that does not declare the resources it counts, and a LimitRange default is what lets pods without those values in.** The two objects work as a pair, and the exam tasks often need both.

The module has three parts. **ResourceQuota Caps A Namespace** creates a quota, reads used against hard, and reads the rejection of a Deployment. **Quota Rejections For Requests, Counts And Storage** reads the messages for a pod without requests, too many objects and too much storage. **LimitRange Sets Defaults And Maximums** gives containers default requests and limits, rejects containers that are too large, and shows the order of the two admission steps.

## Learning objectives

After this module you can:

- Cap a namespace's total CPU and memory requests and limits, and its object counts, with a ResourceQuota.
- Read used against hard in `kubectl describe resourcequota`.
- Diagnose a pod or ReplicaSet that a quota rejects, from the `Forbidden` message and the events of the ReplicaSet.
- Set default requests and limits, and a minimum and a maximum for each container, with a LimitRange.
- Explain why a compute quota requires every new pod to declare requests, and how a LimitRange default solves that.

## Before you start

You need Kubernetes basics: pods, Deployments, ReplicaSets, namespaces, and the commands `kubectl get`, `kubectl apply`, `kubectl describe` and `kubectl scale`. You should know that a request is the CPU or memory the scheduler reserves for a container, and that a limit is the most a container may use.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. It has two tenant namespaces, and neither has a quota or a LimitRange yet:

| Namespace | Workloads |
| --- | --- |
| `starfleet` | `scout` (`podinfo`, with requests and a memory limit) and `shuttle` (a client pod with `curl`) |
| `outpost` | `scout` and `shuttle` as above, and `probe` (`go-httpbin`) with no resources at all |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it. Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
