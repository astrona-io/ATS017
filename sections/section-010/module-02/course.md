# Place Workloads With Affinity, Taints And Topology Spread

Left alone, the scheduler puts a new pod on any node that has room for its requests. That is fine for one test pod. It is not fine when a database must run on the nodes with fast disks, when one team paid for its own nodes, or when three replicas of a service all land on the same node and one node failure takes the whole service down.

Kubernetes gives you three tools for this, and each one answers a different question. **Node affinity** answers "which nodes may this pod use?" from the node's labels. **Taints and tolerations** answer "which pods may this node accept?" from the node's side. **Pod anti-affinity and topology spread constraints** answer "how should the replicas of one workload be spread out?" from the pods already running.

Keep one sentence in mind for this module: **the scheduler first filters out every node a pod may not use, and only then scores the nodes that are left.** Required rules and taints filter; preferences only change the score. Almost every surprise in this module comes from mixing up the two steps.

The module has three parts. **Node Labels And Node Affinity** reads the labels on the playground's nodes and pins pods to them with `nodeSelector` and node affinity, both required and preferred. **Taints And Tolerations** reserves a node for one tenant and shows why a toleration alone does not move a pod there. **Spreading Replicas** keeps replicas apart with pod anti-affinity and spreads them evenly across zones with a topology spread constraint.

## Learning objectives

After this module you can:

- Pin pods to labelled nodes with required node affinity, and prefer nodes with preferred node affinity.
- Reserve a node for one workload with a `NoSchedule` taint and a matching toleration.
- Explain from pod placement why a toleration alone does not move a pod onto a tainted node.
- Keep replicas apart with pod anti-affinity on `kubernetes.io/hostname`.
- Spread replicas evenly across zones with a topology spread constraint, and read the effect of `maxSkew` and `whenUnsatisfiable`.
- Diagnose a `Pending` pod caused by an unmatched affinity rule or an untolerated taint from its `FailedScheduling` message.

## Before you start

You need Kubernetes basics: pods, Deployments, labels and selectors, namespaces, and the commands `kubectl get`, `kubectl apply`, `kubectl describe` and `kubectl scale`. You should know that each container's CPU and memory requests decide whether a pod fits on a node; this module adds the rules that decide which nodes it may use.

Your playground is a `kind` cluster with three nodes, running Kubernetes 1.35: one control plane node and two worker nodes. The control plane node carries the taint `node-role.kubernetes.io/control-plane:NoSchedule`, so ordinary pods never run there. The two workers are labelled like this:

| Node | Labels | Taint |
| --- | --- | --- |
| `...-worker` | `topology.kubernetes.io/zone=zone-a`, `disktype=ssd` | none |
| `...-worker2` | `topology.kubernetes.io/zone=zone-b` | `dedicated=outpost:NoSchedule` |

The full node names start with the playground's name, for example `astro-ats-017-playground-010-02-worker`. The namespace `starfleet` runs `scout` (three replicas of `podinfo`, a small web application, with no placement rules) and `shuttle`, a client pod. The namespace `outpost` runs `probe`, an HTTP echo server, with no toleration. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
