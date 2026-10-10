# Route Traffic With The Gateway API

A Service gives a group of pods one stable address inside the cluster. It does not decide which pod gets a request by its path or header, and it does not let several teams share one entry point safely. For that, Kubernetes has the **Gateway API**: a set of Kubernetes objects that describe how HTTP traffic enters the cluster and which Service each request reaches.

The Gateway API splits the job into three objects, and each one belongs to a different role. A **GatewayClass** names the controller that does the work, and the cluster operator installs it. A **Gateway** opens a listener on a port, and the platform team owns it. An **HTTPRoute** holds the routing rules for one application, and the application team writes it. A request goes through all three before it reaches a pod.

Keep one sentence in mind for this module: **an HTTPRoute does nothing until a Gateway accepts it, and its status tells you whether it did.** Most routing problems on the exam are not wrong rules but routes that never attached, or that point at a Service they may not use.

The module has three parts. **Gateway Classes, Gateways And Listeners** reads the GatewayClass in the playground, creates a Gateway and reads its status and address. **HTTPRoute Matches, Backends And Weights** sends requests to different Services by path and by header, and splits traffic between two Services by weight. **Route Status And Cross-Namespace Routing** breaks a route on purpose, reads its conditions, and lets routes and backends in another namespace in with `allowedRoutes` and a ReferenceGrant.

## Learning objectives

After this module you can:

- Name the roles of GatewayClass, Gateway and HTTPRoute and which team owns each.
- Create a Gateway listener and attach an HTTPRoute to it with `parentRefs`.
- Route requests by path and by header to two backend Services.
- Split traffic between two backends with `backendRefs` weights.
- Diagnose a route that does not attach from its `status.parents` conditions (`Accepted`, `ResolvedRefs`).
- Allow a route from another namespace with `allowedRoutes`, and a backend in another namespace with a ReferenceGrant.

## Before you start

You need Kubernetes basics: pods, Deployments, Services, labels and namespaces, and the commands `kubectl get`, `kubectl apply`, `kubectl exec` and `kubectl get -o jsonpath`. You should know that a Service has a cluster-internal IP address and forwards requests to the pods its selector matches.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. The Gateway API objects and a controller that implements them are already installed, and one GatewayClass is ready. There is no Gateway and no HTTPRoute yet. The playground has these namespaces and workloads:

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `bridge` | An NGINX web server that answers `bridge front end` |
| `starfleet` | `scout` | `podinfo`, a small web application; `/api/info` returns JSON with its version |
| `starfleet` | `probe` | `go-httpbin`, an HTTP echo server; `/headers` and `/get` return the request as JSON |
| `starfleet` | `shuttle` | A client pod with `curl`; every test request is sent from here |
| `outpost` | `probe` | A second `go-httpbin` that belongs to another team |

Each of `bridge`, `scout` and `probe` has a Service on port `80`. A `kind` cluster has no cloud load balancer, so every request in this module is sent from the `shuttle` pod to the Gateway's address inside the cluster. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
