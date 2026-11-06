# Solution Walkthrough

Repair the listener permission first, then the selected listener, routing
rules and backend permission. An HTTPRoute maps matching HTTP (Hypertext Transfer Protocol) requests to
Services. A ReferenceGrant permits an object reference across namespaces.

| Goal | Object and field |
| --- | --- |
| Permit route attachment | Gateway listener `allowedRoutes` |
| Select the listener | HTTPRoute `parentRefs.sectionName` |
| Choose a backend | HTTPRoute `rules.matches` and `backendRefs` |
| Permit a backend in another namespace | ReferenceGrant in the Service namespace |

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-01/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Inspect the rejected attachment

Read the Gateway and both routes. No checks pass yet.

```sh
kubectl -n starfleet get gateway starfleet-gateway -o yaml
kubectl -n outpost get httproute team-route -o yaml
kubectl -n outpost get httproute relay -o yaml
```

The Gateway listener allows `Same`, which means only routes from
`starfleet`. The route selects `web`, while the listener is named `http`.
Read each parent condition's reason and message. Fixing one attachment
fault can reveal the other; do not rely on one particular reason appearing
first.

## Step 2: Repair the listener and default route

Save this as `gateway-starfleet.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: starfleet-gateway
  namespace: starfleet
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              kubernetes.io/metadata.name: outpost
```

Apply it:

```sh
kubectl apply -f gateway-starfleet.yaml
```

The namespace selector matches the `outpost` Namespace's built-in name
label. It permits that team's routes. The listener remains HTTP on port 80.
A ReferenceGrant is not required for a route to attach across namespaces.

Save this as `httproute-team.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: team-route
  namespace: outpost
spec:
  parentRefs:
    - name: starfleet-gateway
      namespace: starfleet
      sectionName: http
  hostnames:
    - team.starfleet.example
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: bridge
          port: 80
```

Apply it:

```sh
kubectl apply -f httproute-team.yaml
```

`parentRefs.namespace` locates the Gateway in `starfleet`. `sectionName`
selects listener `http`. The hostname isolates the team's requests, and the
prefix `/` forwards them to its local `bridge` Service.

Then check the result:

```sh
kubectl -n outpost get httproute team-route -o yaml
kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{.status.addresses[0].value}{"\n"}'
```

Look for fresh `Accepted=True` and `ResolvedRefs=True` on `team-route`.
Copy the address and replace `<GATEWAY_ADDRESS>` below:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -fsS -H 'Host: team.starfleet.example' http://<GATEWAY_ADDRESS>/
```

Look for `outpost front end`. The watch terminal should show **attachment**
passing. `relay` can now attach too, but its backend reference still needs
permission.

## Step 3: Add the longer path prefix

Save this as `httproute-team.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: team-route
  namespace: outpost
spec:
  parentRefs:
    - name: starfleet-gateway
      namespace: starfleet
      sectionName: http
  hostnames:
    - team.starfleet.example
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: scout
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: bridge
          port: 80
```

Apply it:

```sh
kubectl apply -f httproute-team.yaml
```

The `/api` prefix is more specific than `/`. `backendRefs.port` is the
Service port, 80, rather than the pod's container port. Applying the whole
route preserves the default rule.

Then check the result:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -fsS -H 'Host: team.starfleet.example' http://<GATEWAY_ADDRESS>/api/info
```

Look for the hostname of a `scout` pod in the response. The watch terminal
should show **attachment** and **path** passing.

## Step 4: Add the header match

Save this as `httproute-team.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: team-route
  namespace: outpost
spec:
  parentRefs:
    - name: starfleet-gateway
      namespace: starfleet
      sectionName: http
  hostnames:
    - team.starfleet.example
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: scout
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /
          headers:
            - name: x-version
              value: canary
      backendRefs:
        - name: probe
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: bridge
          port: 80
```

Apply it:

```sh
kubectl apply -f httproute-team.yaml
```

The header and path inside one match must both match. The default header
type is `Exact`. At path `/`, adding the header makes this rule more
specific than the default rule. At `/api/info`, the longer path rule wins
before the proxy compares header counts.

Then check both cases:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -fsS -H 'Host: team.starfleet.example' -H 'x-version: canary' http://<GATEWAY_ADDRESS>/headers
kubectl -n starfleet exec deploy/shuttle -- curl -fsS -H 'Host: team.starfleet.example' -H 'x-version: canary' http://<GATEWAY_ADDRESS>/api/info
```

Look for the echoed canary header in the first response and a `scout`
hostname in the second. The watch terminal should show **attachment**,
**path** and **header** passing.

## Step 5: Permit the relay backend

Save this as `referencegrant-outpost-bridge.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: ReferenceGrant
metadata:
  name: allow-outpost-bridge
  namespace: starfleet
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: outpost
  to:
    - group: ''
      kind: Service
      name: bridge
```

Apply it:

```sh
kubectl apply -f referencegrant-outpost-bridge.yaml
```

The grant lives in `starfleet`, where the target Service lives. `from`
permits HTTPRoutes in `outpost`; `to` restricts the target to Service
`bridge`. The empty group is the Kubernetes core API group. The existing
`relay` route needs no backend change.

Then check the result:

```sh
kubectl -n outpost get httproute relay -o yaml
kubectl -n starfleet exec deploy/shuttle -- curl -fsS -H 'Host: relay.starfleet.example' http://<GATEWAY_ADDRESS>/
```

Look for fresh positive parent conditions and the body `starfleet front
end`. The watch terminal should show **reference** passing too. All four
checks should now pass. Wait for reconciliation if a condition still
reports the older generation.

## Step 6: Submit

Stop the watch command with Ctrl+C. Submit once from the host terminal to
record the result and finish the attempt:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-01/labs/lab-01
```

## If a check stays red

- **attachment:** Compare the listener name with `sectionName`, and check
  that the namespace selector matches `outpost`, not a label on the route.
- **path:** Keep the `/api` match as `PathPrefix` and use Service port 80.
- **header:** Put the header and prefix `/` inside the same match. Keep the
  longer `/api` rule and the default backend.
- **reference:** Put the grant in `starfleet` and name `outpost` as the
  source namespace. Check `relay` for `RefNotPermitted` and compare its
  condition generation with `metadata.generation`.
