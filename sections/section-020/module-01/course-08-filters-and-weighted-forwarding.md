# Filters And Weighted Forwarding

A public path often differs from the backend's path. Sending `/inspect/headers` unchanged to `probe` does not ask for its `/headers` endpoint. An HTTPRoute filter changes a request or returns a redirect after a rule matches. This lets you preserve a public address while choosing what the backend receives.

An HTTPRoute is the Gateway API (Application Programming Interface) object that defines HTTP (Hypertext Transfer Protocol) request routing. A filter is an operation attached to a rule or backend reference. This example needs `starfleet-gateway` in `starfleet`, listener `http`, and the `probe` Service on port 80 in the same namespace.

<!-- astrona:playground:renew -->

Save this as `httproute-filters.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: filters
  namespace: starfleet
spec:
  parentRefs:
    - name: starfleet-gateway
      sectionName: http
  hostnames:
    - filters.starfleet.example
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /inspect
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            set:
              - name: x-route-owner
                value: starfleet
            add:
              - name: x-route-tag
                value: inspected
            remove:
              - x-debug-token
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /
      backendRefs:
        - name: probe
          port: 80
    - matches:
        - path:
            type: Exact
            value: /old-inspect
      filters:
        - type: RequestRedirect
          requestRedirect:
            path:
              type: ReplaceFullPath
              replaceFullPath: /inspect/headers
            statusCode: 302
```

Apply it:

```sh
kubectl apply -f httproute-filters.yaml
```

Then check the result. Read the Gateway address and use it in these requests:

```sh
kubectl -n starfleet get httproute filters -o yaml
kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{.status.addresses[0].value}{"\n"}'
kubectl -n starfleet exec deploy/shuttle -- curl -sS -H 'Host: filters.starfleet.example' -H 'x-route-owner: caller' -H 'x-debug-token: temporary' http://<GATEWAY_ADDRESS>/inspect/headers
kubectl -n starfleet exec deploy/shuttle -- curl -sS -i -H 'Host: filters.starfleet.example' http://<GATEWAY_ADDRESS>/old-inspect
```

In the first response, look for `X-Route-Owner` set to `starfleet`, `X-Route-Tag` containing `inspected`, and no `X-Debug-Token`. The successful echo comes from the `/headers` endpoint: the proxy replaced the matched prefix `/inspect` with `/`. In the second response, look for status 302 and a `Location` header ending in `/inspect/headers`. Do not use `curl -L` here; following the redirect would hide that first response.

## Matching happens before modification

The proxy matches the original path and headers before applying these filters. Adding a canary header with `RequestHeaderModifier` does not make the request select a different rule. `set` replaces an existing header value, `add` appends a value, and `remove` removes the named header. Header names are case insensitive. A header name may appear in only one operation in a filter; using the same name in multiple operations is invalid.

`URLRewrite` changes the request forwarded upstream. The client keeps its original address and sees the backend's response. `ReplacePrefixMatch` preserves the suffix after a whole-element prefix. It requires exactly one `PathPrefix` match in the rule in this API version. `ReplaceFullPath` replaces the entire path. A rewrite can also set `hostname`, which changes the upstream Host header.

`RequestRedirect` returns a response to the client; it does not forward that request to a backend. A client can then make a new request to `Location`. Keep `backendRefs` out of a redirect rule. You may set a redirect's `scheme`, `hostname`, `port` and path. A redirect to `https` does not create a TLS (Transport Layer Security) listener or certificate; those must already exist if the new address is to serve traffic.

A rule cannot combine `URLRewrite` and `RequestRedirect`. The pinned API schema rejects that combination. A controller can report `Accepted=False` with `IncompatibleFilters` for incompatible filter configurations it rejects during reconciliation. Other unsupported values can appear as `UnsupportedValue`. Read the API server error first if the object was never stored.

## Weights apply inside the winning rule

A backend weight is a relative share among the backend references of one rule. It never helps a rule win. To isolate that behavior, use a separate hostname and two valid backend references.

Save this as `httproute-weight-check.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: weight-check
  namespace: starfleet
spec:
  parentRefs:
    - name: starfleet-gateway
      sectionName: http
  hostnames:
    - weights.starfleet.example
  rules:
    - backendRefs:
        - name: bridge
          port: 80
          weight: 3
        - name: scout
          port: 80
          weight: 1
```

Apply it:

```sh
kubectl apply -f httproute-weight-check.yaml
```

Then send a sample of requests:

```sh
kubectl -n starfleet get httproute weight-check -o yaml
kubectl -n starfleet exec deploy/shuttle -- sh -c 'for request in 1 2 3 4 5 6 7 8 9 10 11 12; do curl -fsS -H "Host: weights.starfleet.example" http://<GATEWAY_ADDRESS>/; done'
```

Replace the address inside the quoted command too. Look for responses from both applications over repeated samples. Each share is its weight divided by the sum: 3 and 1 express the same split as 75 and 25. An omitted weight defaults to 1; weight 0 receives no traffic. A small sample does not prove an exact percentage.

A weight is not failover priority. If a rule contains an invalid backend reference, the proxy must reject the corresponding share rather than silently send that share to a healthy backend. Read `ResolvedRefs` before interpreting a traffic sample. Rule-level filters apply to requests matching the rule; a backend-level filter applies only when that backend is chosen, where the implementation supports it. Do not assume every controller supports every extended filter or filter ordering.

You can now distinguish a client-visible redirect from an upstream rewrite, and separate rule selection from weighted backend selection. Fresh conditions and a response that exposes the changed path or header together give stronger evidence than either one alone.

## Common pitfalls

> [!WARNING]
> - **Using `curl -L` to inspect a redirect.** Read the first status and `Location` before following it.
> - **Rewriting a prefix on an `Exact` match.** `ReplacePrefixMatch` requires a `PathPrefix` match.
> - **Treating weights as fallback order.** An invalid backend can fail its share instead of passing it to another backend.
