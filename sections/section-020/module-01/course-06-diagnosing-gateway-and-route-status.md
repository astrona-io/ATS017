# Diagnosing Gateway And Route Status

A Gateway can be programmed while an application route is rejected. A successful `kubectl apply` only proves that the API server stored an object. To find where traffic stops, read conditions on the Gateway, its listener and the HTTPRoute's selected parent, then send a request.

A condition is a named status entry with a boolean-like `status`, a short `reason`, a human-readable `message` and an `observedGeneration`. An HTTPRoute is the Gateway API (Application Programming Interface) object that maps matching HTTP (Hypertext Transfer Protocol) requests to backends. This example needs the Gateway `starfleet-gateway` with the listener `http` on port 80 and the `bridge` Service in `starfleet`.

<!-- astrona:playground:renew -->

Save this as `httproute-status-check.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: status-check
  namespace: starfleet
spec:
  parentRefs:
    - name: starfleet-gateway
      sectionName: web
  hostnames:
    - status.starfleet.example
  rules:
    - backendRefs:
        - name: bridge
          port: 80
```

Apply it:

```sh
kubectl apply -f httproute-status-check.yaml
```

Then check the result:

```sh
kubectl -n starfleet get gateway starfleet-gateway -o yaml
kubectl -n starfleet get httproute status-check -o yaml
kubectl -n starfleet describe httproute status-check
```

Look for `Accepted=False` on the route with `NoMatchingParent`: no listener is named `web`. The Gateway may still show `Programmed=True` because the proxy is configured for its valid listener. When several faults exist, fix the reported one and read status again; the controller need not expose every fault at once.

Change `sectionName: web` to `sectionName: http` in the saved file. Apply it:

```sh
kubectl apply -f httproute-status-check.yaml
```

Then check the result:

```sh
kubectl -n starfleet get httproute status-check -o jsonpath='{range .status.parents[*]}{.parentRef.name}{"/"}{.parentRef.sectionName}{" "}{.controllerName}{"\n"}{range .conditions[*]}{.type}{"="}{.status}{" "}{.reason}{" generation="}{.observedGeneration}{" "}{.message}{"\n"}{end}{end}'
kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{range .status.listeners[*]}{.name}{" attached="}{.attachedRoutes}{"\n"}{range .conditions[*]}{.type}{"="}{.status}{" "}{.reason}{"\n"}{end}{end}'
```

The route should now have `Accepted=True` and `ResolvedRefs=True` for listener `http`. Compare each condition's `observedGeneration` with that object's `metadata.generation` in the full YAML. An older generation describes an earlier specification. `lastTransitionTime` records a status transition; it is not the time of every reconciliation.

## Read the right status level

The controller reports status. `Gateway.status.conditions` summarizes the Gateway, while `Gateway.status.listeners` names each listener and its conditions. `attachedRoutes` counts routes attached to that listener; it does not count healthy backends. `HTTPRoute.status.parents` has a separate entry for each reported parent, including `parentRef`, `controllerName` and conditions. Check the entry for the intended Gateway and listener.

| Location and condition | What to establish | Common reasons to inspect |
| --- | --- | --- |
| Gateway `Accepted` | The controller accepts the Gateway specification | `Accepted`, `ListenersNotValid`, `InvalidParameters`, `UnsupportedAddress`, `Pending` |
| Gateway `Programmed` | Configuration has reached the data plane | `Programmed`, `Pending`, `Invalid`, `NoResources`, `AddressNotAssigned`, `AddressNotUsable` |
| Listener `Accepted` | This listener is supported | `Accepted`, `UnsupportedProtocol`, `PortUnavailable`, `UnsupportedValue` |
| Listener `Programmed` | This listener is configured in the data plane | `Programmed`, `Pending`, `Invalid` |
| Listener `ResolvedRefs` | Its references, such as a certificate, resolve | `ResolvedRefs`, `InvalidCertificateRef`, `RefNotPermitted`, `InvalidRouteKinds` |
| HTTPRoute parent `Accepted` | This parent accepts the route | `Accepted`, `NoMatchingParent`, `NotAllowedByListeners`, `NoMatchingListenerHostname`, `UnsupportedValue` |
| HTTPRoute parent `ResolvedRefs` | Referenced backends exist and are permitted | `ResolvedRefs`, `BackendNotFound`, `RefNotPermitted`, `InvalidKind`, `UnsupportedProtocol` |

`NotAllowedByListeners` points to route kind or namespace permissions. `NoMatchingListenerHostname` points to a missing intersection between route and listener hostnames. `BackendNotFound` calls for checking the Service name, namespace and port. `RefNotPermitted` calls for permission in the target namespace, not a new Service.

In Gateway API v1.6.1, the experimental Gateway-level `ResolvedRefs` condition summarizes reference resolution too. `ListenersNotResolved` points down to listener conditions; `InvalidClientCertificateRef` concerns a Gateway backend client certificate, and `RefNotPermitted` can concern its cross-namespace reference. The addon may not emit every experimental condition. Read the listener and route conditions even when that summary is absent. HTTPRoute's portable parent conditions are `Accepted` and `ResolvedRefs`; do not wait for a route-level `Programmed` condition as proof of attachment.

## Prove the data path

Events provide extra clues but are not a required record of every rejection. If there are no events, continue with conditions and the response. Read the Gateway address and substitute it below:

```sh
kubectl -n starfleet get events --field-selector involvedObject.name=starfleet-gateway
kubectl -n starfleet get events --field-selector involvedObject.name=status-check
kubectl -n starfleet get endpointslices -l kubernetes.io/service-name=bridge
kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{.status.addresses[0].value}{"\n"}'
kubectl -n starfleet exec deploy/shuttle -- curl -sS -i -H 'Host: status.starfleet.example' http://<GATEWAY_ADDRESS>/
```

Look for the `bridge front end` body. A proxy response of 404 can mean no route matched, but a backend can also return 404. An invalid backend reference can make a matching rule return 500; an unavailable backend can lead to 503. The response alone does not identify the fault. Compare it with fresh route conditions and the Service's endpoints.

You can now separate an invalid listener, a rejected attachment and an unresolved backend. Once the intended parent has fresh positive conditions, requests prove whether the programmed data path actually serves the application.

## Common pitfalls

> [!WARNING]
> - **Stopping at Gateway `Programmed=True`.** A rejected HTTPRoute can coexist with a healthy Gateway.
> - **Reading stale success.** Compare `observedGeneration` with `metadata.generation` after an edit.
> - **Waiting for events instead of reading conditions.** A controller may explain a rejection only in status.
