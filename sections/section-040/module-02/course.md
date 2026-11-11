# Attribute Cost By Label And Find Idle Spend

A cost report is only useful if every dollar has an owner. OpenCost can split the cost of a cluster by namespace and by controller, but a team often owns workloads in several namespaces, and one namespace often holds workloads of several teams. To answer "what does the navigation team cost?", the cost must be grouped by a label on the pods.

This module uses the `team` label to attribute cost. It shows how a missing label turns cost into an anonymous bucket, how to read the cost of each team, and how to find the part of the bill that no team owns. That part is idle cost: the cost of node capacity that no pod requests.

Keep one sentence in mind for this module: **OpenCost groups cost by the labels of pods, so a workload without the label is charged to nobody, and capacity that nobody requests is charged to the cluster as idle cost.** Every part below explains where the label must be, how to query the groups, or what to change to reduce the cost.

The module has four parts. **Labels As The Unit Of Showback** explains showback and chargeback, shows where OpenCost reads the label from and finds the cost that has no owner. **Aggregate By Label, Namespace And Controller** groups the cost in several ways, fixes the missing label and reports a closed window. **Find Idle And Shared Cost** adds the idle cost, shares it between teams, and shows what a right-sized request does to it.

**Rank Deployment Cost Before Changing Replicas** preserves a closed window and uses its ranking to make a controlled replica change.

## Learning objectives

After this module you can:

- Explain showback and chargeback, and say which label OpenCost needs on a pod to attribute its cost to a team.
- Query the allocation API with `aggregate=label:team`, and find the bucket `__unallocated__` and the workloads in it.
- Group cost by namespace, controller and label together, and keep the cost of a report repeatable with a closed window.
- Add `includeIdle=true` and `shareIdle=true`, and explain how idle cost differs from cost without a label.
- Lower the requests of an inefficient workload and show that its cost moves from the workload to idle cost.

## Before you start

You need Kubernetes basics: pods, Deployments, Services, namespaces, labels, and the commands `kubectl get`, `kubectl patch` and `kubectl exec`. You should know what a request is, and that OpenCost reads requests and usage from Prometheus to compute a cost. You should also know how to read JSON with `jq`.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. A `kind` cluster has no cloud bill, so OpenCost uses its default on-premises price list. The costs in this module are small dollar amounts from that list, not real money. The playground installs a small Prometheus and OpenCost 1.121.3 with Helm. Prometheus is plumbing here: it stores the usage and the requests that OpenCost reads. The workloads are these:

| Workload | Label `team` | What it is |
| --- | --- | --- |
| `starfleet/scout` | `navigation` | `podinfo`, a small web application, with requests of `100m` CPU and `64Mi` memory |
| `starfleet/probe` | `navigation` | `go-httpbin`, an HTTP echo server, with requests of `50m` and `32Mi` |
| `starfleet/shuttle` | `navigation` | A client pod with `curl` that sends requests to `scout` and `probe` in a loop |
| `starfleet/scout-overprovisioned` | `science` | `podinfo` with requests of `1500m` and `1Gi`, far more than it uses |
| `outpost/probe` | `research` | `go-httpbin` with requests of `100m` and `64Mi` |
| `outpost/archive` | none | `go-httpbin` with requests of `300m` and `256Mi`. No pod of this Deployment has a `team` label |

OpenCost needs about six minutes of samples before the first cost appears, and about fifteen minutes before the numbers settle. The parts are written so that you can read ahead while the data builds up. Every command runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-02/playground
> ```
