# Isolate Traffic With NetworkPolicy

By default, every pod in a Kubernetes cluster can send a request to every other pod, in every namespace. That is easy for a first test, but it is not safe for a shared cluster. One compromised or badly written pod can reach every database and every other team's service.

A **NetworkPolicy** is a namespaced Kubernetes object that selects pods and lists the traffic they allow. The network plugin of the cluster (the CNI plugin, Container Network Interface) reads the policies and drops every packet that no policy allows. The API server only stores the policy; without a plugin that enforces it, a NetworkPolicy does nothing.

Keep one sentence in mind for this module: **as soon as one policy selects a pod for a direction, everything in that direction is denied except what some policy allows.** Policies only ever add allowed traffic. There is no "deny" rule, and the order of policies does not matter.

The module has three parts. **Default Deny And How Policies Select Pods** proves that every request works at the start, then blocks all incoming traffic in a namespace and finds the policies that select a pod. **Allowing Flows With Pod And Namespace Selectors** opens single flows with `podSelector`, `namespaceSelector` and ports, and shows the difference between one `from` item with two selectors and two items. **Egress Rules And DNS** blocks outgoing traffic, shows that name lookups break first, and restores DNS with an egress rule to `kube-dns`.

## Learning objectives

After this module you can:

- Apply a default-deny ingress and egress policy to a namespace and prove that requests now time out.
- Allow one flow between two workloads with `podSelector` and `ports`.
- Allow traffic from another namespace with `namespaceSelector`, and tell apart AND and OR selector combinations.
- Restore DNS for selected pods with an egress rule to `kube-dns` on port 53, UDP and TCP.
- Diagnose which policy blocks a request by listing the policies that select a pod.

## Before you start

You need Kubernetes basics: pods, Deployments, Services, labels and selectors, namespaces, and the commands `kubectl get`, `kubectl apply`, `kubectl describe` and `kubectl exec`. You should know that a Service forwards requests from its port to a `targetPort` on the selected pods.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. Its default network plugin, kindnet, enforces NetworkPolicy. No NetworkPolicy exists at the start, so every request succeeds and you see each policy remove traffic. The playground has these workloads:

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | `podinfo`, a small web application on container port `9898`, behind the Service `scout` on port `80` |
| `starfleet` | `probe` | `go-httpbin`, an HTTP echo server on container port `8080`, behind the Service `probe` on port `80` |
| `starfleet` | `shuttle` | A client pod with `curl` |
| `outpost` | `probe` | A second `go-httpbin` for another team, behind its own Service `probe` |
| `outpost` | `shuttle` | A second client pod with `curl`, for requests from the other namespace |

Every namespace carries the label `kubernetes.io/metadata.name` with its own name, which Kubernetes sets automatically. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
