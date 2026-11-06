# Summary

The Gateway API describes how HTTP traffic enters a cluster and which Service each request reaches. This module built that path on a `kind` cluster: a Gateway with one listener, routes that choose a backend by path, header, host name and weight, the precedence order that settles overlapping rules, the status conditions that say whether a route works at all, the listener and grant permissions that cross namespace boundaries, and the filters that change a request on its way.

## What you learned

The Gateway API splits the job between three objects and three roles. The cluster operator installs a controller and its GatewayClass, which names the controller in `spec.controllerName`. The platform team creates a Gateway that names the class in `gatewayClassName` and opens listeners, each with a name, a protocol and a port. The application team writes HTTPRoutes that point up at a Gateway with `parentRefs` and down at Services with `backendRefs`. The objects do nothing without a controller, so read the class name from the cluster before you write a Gateway, and read the Gateway's address from `status.addresses` once it is `Accepted` and `Programmed`.

An HTTPRoute rule has `matches`, optional `filters` and `backendRefs`. Conditions inside one match must all be true, while separate matches are alternatives, and a rule with no `matches` catches every request. Several `backendRefs` with a `weight` each split requests at random in proportion to the weights; an omitted weight is `1`, a weight of `0` drains a backend, and an invalid backend fails its share with `500` instead of handing it to another.

When rules overlap, the proxy first narrows by listener and route hostname, then compares exact paths, prefix length, method, header counts and query parameter counts. Remaining ties across routes use creation time and then namespace/name; ties inside one route use rule order. A canary header does not override a longer prefix, and weights never help a rule win.

The API server accepts any valid route, so the proof is in `status.parents`. `Accepted` says whether the Gateway let the route attach; `NoMatchingParent` means a listener name or Gateway that does not exist, and `NotAllowedByListeners` means the listener's `allowedRoutes` does not include the route's namespace or kind. `ResolvedRefs` says whether the backends are usable; `BackendNotFound` means a missing Service, and `RefNotPermitted` means a Service in another namespace without a ReferenceGrant. Gateway, listener and route conditions are separate levels, and a condition is only fresh when its `observedGeneration` matches `metadata.generation`.

Filters run after matching. A header modifier changes what the backend receives, a rewrite changes the upstream path or host, and a redirect answers the client with a `Location` header instead of forwarding. A rule cannot combine a redirect with backends or with a rewrite.

The key facts to remember are these:

- `allowedRoutes.namespaces.from` is `Same` by default; with `Selector`, the Gateway's own namespace must match too.
- A ReferenceGrant lives in the namespace of the target and lists the allowed `from` kinds and namespaces; grants are additive and cannot deny.
- `404` from the proxy means no rule matched; `500` means a rule matched but its backend is not usable.
- The listener's `attachedRoutes` counter counts accepted routes and is the quickest check of how many routes reached it.

<!-- astrona:playground:destroy -->
