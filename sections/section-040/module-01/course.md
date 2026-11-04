# Read Cost Allocation With OpenCost

A cluster has one bill, and many teams share it. A team that wants to spend less needs to know which of its workloads cost the most, and which of them pay for capacity they never use. The Kubernetes API does not answer these questions. It knows what each pod requests, but it does not know the price of a core or the time a pod ran.

**Cost allocation** is the work of splitting the cost of a cluster across namespaces, controllers, pods and labels. **OpenCost** is a CNCF (Cloud Native Computing Foundation) tool that does this split. It reads the requests and the usage of every container from Prometheus, multiplies them by a price list, and serves the result through an HTTP API and a web page.

Keep one sentence in mind for this module: **OpenCost charges each container for the larger of what it requests and what it uses, so a request that is too high costs money even when the container is idle.** Everything in the parts below either explains where the numbers come from, shows how to ask for them, or shows how to read them.

The module has five parts. **How OpenCost Computes Cost Allocation** follows a cost from the three inputs (prices, requests and usage) to dollars. **Install OpenCost And Check Its Data Sources** shows what OpenCost depends on and how to prove that each dependency works. **Query The Allocation API** asks for the cost of a window of time, grouped by namespace, controller, pod or label. **Read Efficiency And Find Waste** reads the efficiency fields and finds the workload that wastes the most of its request. **Change Prices And Check Metrics** changes the custom rates, uses `kubectl cost --opencost`, and saves pod information and a scrape error from Prometheus.

## Learning objectives

After this module you can:

- Name the data OpenCost needs (Prometheus metrics and node prices) and say where each input comes from on a cluster without cloud billing.
- Check that OpenCost reaches Prometheus and has a price list, and explain why a missing price list gives a cost of zero.
- Query the allocation API for a window and an aggregate with `kubectl get --raw`, and read `cpuCost`, `ramCost`, `pvCost` and `totalCost`.
- Explain how OpenCost uses the larger of the request and the usage, and read `cpuEfficiency`, `ramEfficiency` and `totalEfficiency`.
- Find the workload that wastes the most of its request, which is not always the workload that costs the most.

- Change the custom price model and check the active rates through OpenCost.
- Use `kubectl cost` with `--opencost` and save namespace-filtered pod metrics and a scrape error.

## Before you start

You need Kubernetes basics: pods, Deployments, Services, namespaces, and the commands `kubectl get`, `kubectl exec` and `kubectl logs`. You should know that CPU is written in millicores (`100m` is one tenth of a CPU core), that memory is written in bytes with a suffix such as `Mi`, and what a request is. You should also know how to read JSON with `jq`.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. A `kind` cluster has no cloud bill, so OpenCost uses its default on-premises price list. The costs in this module are small dollar amounts from that list, not real money. The playground installs a small Prometheus and OpenCost 1.121.3 with Helm. Prometheus stores the usage and requests that OpenCost reads. You also query pod information and inspect scrape errors. The terminal has `kubectl-cost` v0.6.6; its `--opencost` flag selects the OpenCost endpoint. One extra scrape job, `probe-broken`, fails on purpose and stays down. The workloads in the namespace `starfleet` and `outpost` are these:

| Workload | What it is |
| --- | --- |
| `starfleet/scout` | `podinfo`, a small web application, with requests of `100m` CPU and `64Mi` memory. It uses almost nothing |
| `starfleet/scout-busy` | The same application started with `--stress-cpu=1` and `--stress-memory=100`. Its requests are `50m` and `64Mi`, so it uses more than it requests |
| `starfleet/probe` | `go-httpbin`, an HTTP echo server, with requests of `50m` and `32Mi` |
| `starfleet/shuttle` | A client pod with `curl` that sends requests to `scout` and `probe` in a loop |
| `outpost/probe` | `go-httpbin` with requests of `200m` and `256Mi`, and a 20Gi PersistentVolumeClaim named `archive` |

OpenCost needs about six minutes of samples before the first cost appears, and about fifteen minutes before the numbers settle. The parts are written so that you can read ahead while the data builds up. Every command runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-01/playground
> ```
