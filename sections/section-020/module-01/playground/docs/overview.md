# Overview: Route Traffic With The Gateway API (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Gateway API
resources installed, a controller running, and several HTTP backends. There is
no task, no `astrona submit` and no pass or fail. Write a Gateway, attach
HTTPRoutes, inspect status, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already
  pointed at it.
- The Gateway API CustomResourceDefinitions (version 1.6.1) are installed, and one
  GatewayClass is available. The controller is installed as playground
  plumbing; the course uses the Gateway API resources.
- Namespace **`starfleet`**:

  | Workload | What it is |
  | --- | --- |
  | `bridge` | NGINX front end that returns `bridge front end` |
  | `scout` | `podinfo` API on port `9898` |
  | `probe` | HTTP echo server on port `8080` |
  | `shuttle` | Client pod with `curl` |

- Namespace **`outpost`**: another `probe` HTTP echo server.
- No Gateway, HTTPRoute or ReferenceGrant exists at the start. The cluster
  has no cloud load balancer: a Gateway gets an address inside the cluster
  (in `status.addresses`), so send requests from `shuttle`.

## Helpers

Paste these once in each new terminal. `gateway_class_name` prints the
GatewayClass name. `gateway_address` prints the in-cluster address of a
Gateway in `starfleet`, read from its status. `ask_gateway` sends one request
from `shuttle` to an address and path, with an optional host name.
`route_status` prints the parent conditions of a route.

```sh
gateway_class_name() {
  kubectl get gatewayclass -o jsonpath='{.items[0].metadata.name}{"\n"}'
}
gateway_address() {
  kubectl -n starfleet get gateway "$1" -o jsonpath='{.status.addresses[0].value}{"\n"}'
}
ask_gateway() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s -H "Host: ${3:-$1}" "http://$1$2"
}
route_status() {
  kubectl -n "$1" get httproute "$2" -o jsonpath='{range .status.parents[*].conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
}
```

Use them like this: `gateway_class_name`,
`GATEWAY=$(gateway_address starfleet-gateway)`, `ask_gateway "$GATEWAY" /api/info`,
`ask_gateway "$GATEWAY" /get split.starfleet.example` and
`route_status starfleet bridge`.

## Practice tasks

- Route `/` to `bridge`, `/api` to `scout` and `/headers` to `probe`, then prove
  each path reaches a different backend.
- Add a header match for `version: canary` that sends traffic to `probe`.
- Change backend weights between `scout` and `probe`, send 20 requests, and
  count how many responses came from each backend.
- Break a backend Service name and read the `ResolvedRefs` condition until you
  can name exactly which reference failed.
- Attach an HTTPRoute from `outpost` to the `starfleet` Gateway, then allow it
  with `allowedRoutes` and a `ReferenceGrant`.
