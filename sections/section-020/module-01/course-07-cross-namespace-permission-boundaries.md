# Cross-Namespace Permission Boundaries

A route can use a Gateway in another namespace without permission to use that namespace's Services. These are separate decisions. The Gateway listener authorizes attachment through `allowedRoutes`; the owner of a target Service authorizes a cross-namespace backend reference through ReferenceGrant. Opening one boundary leaves the other closed.

A ReferenceGrant is a namespaced Gateway API (Application Programming Interface) object that permits specified kinds from other namespaces to reference objects in its own namespace. The playground needs the `starfleet-gateway` Gateway in `starfleet`, with listener `http` allowing HTTPRoutes from `outpost`, and the `probe` Service on port 80 in `starfleet`.

<!-- astrona:playground:renew -->

Save this as `httproute-outpost-inspect.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: outpost-inspect
  namespace: outpost
spec:
  parentRefs:
    - name: starfleet-gateway
      namespace: starfleet
      sectionName: http
  hostnames:
    - inspect.starfleet.example
  rules:
    - backendRefs:
        - name: probe
          namespace: starfleet
          port: 80
```

Apply it:

```sh
kubectl apply -f httproute-outpost-inspect.yaml
```

Then check the result:

```sh
kubectl -n outpost get httproute outpost-inspect -o yaml
kubectl -n starfleet get referencegrants
kubectl -n starfleet get service probe
```

Look for `Accepted=True` and `ResolvedRefs=False` with `RefNotPermitted`, provided no existing grant already permits this reference. Although the Gateway and Service share a namespace, permission depends on the **route's** namespace, here `outpost`. A grant in `outpost` that allows routes from `starfleet` describes the reverse direction and cannot help.

Save this as `referencegrant-probe-inspect.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: ReferenceGrant
metadata:
  name: allow-outpost-probe
  namespace: starfleet
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: outpost
  to:
    - group: ""
      kind: Service
      name: probe
```

Apply it:

```sh
kubectl apply -f referencegrant-probe-inspect.yaml
```

Then check the result. Read the Gateway address and use it in the request:

```sh
kubectl -n outpost get httproute outpost-inspect -o yaml
kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{.status.addresses[0].value}{"\n"}'
kubectl -n starfleet exec deploy/shuttle -- curl -sS -i -H 'Host: inspect.starfleet.example' http://<GATEWAY_ADDRESS>/headers
```

The route should report `ResolvedRefs=True`. Look for a successful response containing the headers echoed by `probe`. The controller rechecks the reference when the grant changes and updates the proxy configuration. ReferenceGrant itself has no status subresource in this version; the route's `ResolvedRefs` condition is the place to read the result.

## How a grant is evaluated

The controller compares the referring object's group, kind and namespace with entries in `from`. It compares the target object's group, kind and optional name with entries in `to`. There must be a matching source and target in a grant in the target namespace. Entries within each list are alternatives. Additional grants add permissions; there is no deny grant that overrides another allow.

`from` does not select individual route names. This grant allows any HTTPRoute in `outpost` to reference Service `probe` in `starfleet`. A target `name` narrows the grant to one Service; leaving it out permits every Service in that namespace. It does not select ports, pods or network connections. A NetworkPolicy can still block traffic after the reference is allowed.

For an HTTPRoute backend Service in the route's own namespace, no grant is needed. Cross-namespace attachment to a Gateway is also an exception: use the listener's `allowedRoutes`, not a ReferenceGrant. A backend Service in a different namespace needs a grant even when the route already uses that namespace's Gateway. Other cross-namespace references, such as a listener's certificate Secret, also need permission in the target namespace.

Remove the permission and inspect the route again:

```sh
kubectl -n starfleet delete referencegrant allow-outpost-probe
kubectl -n outpost get httproute outpost-inspect -o yaml
```

After reconciliation, `ResolvedRefs` should return to `False` with `RefNotPermitted`, unless another grant still permits the reference. The attachment can remain accepted. Restore the permission by applying the saved grant file again if you want the route to keep serving.

You can now identify which namespace owns each permission and why acceptance alone does not authorize a backend. This distinction also keeps repairs narrow: change the listener for attachment and the target namespace's grant for the backend reference.

## Common pitfalls

> [!WARNING]
> - **Using the Gateway namespace as the source.** `from.namespace` names the namespace of the referring HTTPRoute.
> - **Trying to deny with a second grant.** Grants are additive; remove every grant that permits an unwanted reference.
> - **Expecting a grant to bypass NetworkPolicy.** Object reference permission does not authorize network packets.

## Your mission: Repair Gateway Route Attachment

You can now diagnose attachment and backend permission failures. The mission asks you to repair a team's route, choose backends by path and header, and allow one cross-namespace backend.

Pause the playground, then start the lab:

```sh
astrona stop ats-017-playground-020-01
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-01/labs/lab-01
```

When the routes serve the required requests, grade your work:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-01/labs/lab-01
```

Then remove the lab and start the playground again:

```sh
astrona destroy ats-017-lab-020-01
astrona start ats-017-playground-020-01
```
