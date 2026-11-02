# Summary

The Gateway API describes how HTTP traffic enters a cluster and which Service each request reaches. This module built that path on a `kind` cluster: a Gateway with one listener, routes that choose a backend by path, header, host name and weight, and the status conditions and permissions that decide whether a route works at all.

## What you learned

The Gateway API splits the job between three objects and three roles. The cluster operator installs a controller and its GatewayClass, which names the controller in `spec.controllerName`. The platform team creates a Gateway that names the class in `gatewayClassName` and opens listeners, each with a name, a protocol and a port. The application team writes HTTPRoutes that point up at a Gateway with `parentRefs` and down at Services with `backendRefs`. The objects do nothing without a controller, so read the class name from the cluster before you write a Gateway, and read the Gateway's address from `status.addresses`.

An HTTPRoute rule has `matches`, optional `filters` and `backendRefs`. Conditions inside one match must all be true, while separate matches are alternatives, and the most specific matching rule wins. A rule with no `matches` catches every request. Several `backendRefs` with a `weight` each split requests at random in proportion to the weights, which is how a share of traffic goes to a new version.

The API server accepts any valid route, so the proof is in `status.parents`. `Accepted` says whether the Gateway let the route attach; `NotAllowedByListeners` means the listener's `allowedRoutes` does not include the route's namespace. `ResolvedRefs` says whether the backends are usable; `BackendNotFound` means a missing Service, and `RefNotPermitted` means a Service in another namespace without a ReferenceGrant. The key facts to remember are these:

- `allowedRoutes.namespaces.from` is `Same` by default; with `Selector`, the Gateway's own namespace must match too.
- A ReferenceGrant lives in the namespace of the target and lists the allowed `from` kinds and namespaces.
- `404` from the proxy means no rule matched; `500` means a rule matched but its backend is not usable.
- The listener's `attachedRoutes` counter is the quickest check of how many routes reached it.

<!-- astrona:playground:destroy -->
