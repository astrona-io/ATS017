# Selector And Port Boundaries

A monitoring client should reach `scout`, but an unrelated Pod must stay blocked. One extra dash in a NetworkPolicy can admit both. A selector matches object labels; a peer is one source in `from` or one destination in `to`. The indentation decides whether two selectors describe one peer or two alternatives.

<!-- astrona:playground:renew -->

Save this as `networkpolicy-scout-observers.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: scout-observers
  namespace: starfleet
spec:
  podSelector:
    matchLabels:
      app: scout
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: outpost
          podSelector:
            matchLabels:
              app: shuttle
      ports:
        - protocol: TCP
          port: http
```

Apply it:

```sh
kubectl apply -f networkpolicy-scout-observers.yaml
```

Then check the result:

```sh
kubectl -n starfleet describe networkpolicy scout-observers
kubectl -n starfleet get deploy scout -o yaml
kubectl -n outpost exec deploy/shuttle -- curl -fsS --max-time 3 http://scout.starfleet/version
```

Look for both selectors in one source entry, and `name: http` with `containerPort: 9898` in the receiving Deployment's Pod template. The named port `http` resolves against the destination Pod's declared container ports. It is not a Service name or the client's source port. TCP means Transmission Control Protocol. Both ingress and egress named ports refer to the destination; use a numeric port when the receiver does not declare a matching name.

## One peer versus two peers

The example requires `app: shuttle` AND membership in `outpost`. If `podSelector` has its own dash under `from`, the two items mean OR: every Pod in `outpost`, plus `app: shuttle` Pods in the policy's own namespace. The local `shuttle` may still reach `scout` through another policy, so use `kubectl describe` and inspect the full set of allows before interpreting that test.

The empty selector `{}` matches everything within its scope. These scopes differ:

| Field | Meaning |
| --- | --- |
| `spec.podSelector: {}` | Every Pod in the policy's namespace |
| Peer `podSelector: {}` alone | Every Pod in the policy's namespace |
| Peer `namespaceSelector: {}` alone | Every Pod in every namespace |
| Namespace selector plus `podSelector: {}` in one peer | Every Pod in the selected namespaces |

An empty rule, such as `ingress: [{}]`, allows every source and port. An empty list, `ingress: []`, grants nothing. An omitted `from` or `ports` field leaves that dimension unrestricted. These distinctions matter more than the object's name.

## Address ranges and exclusions

An `ipBlock` matches an Internet Protocol (IP) address range in Classless Inter-Domain Routing (CIDR) notation. Its `except` list subtracts smaller ranges from that peer only. It is useful for external address ranges; Pod labels remain a better choice for changing Pod addresses.

Save this as `networkpolicy-shuttle-address-range.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: shuttle-address-range
  namespace: starfleet
spec:
  podSelector:
    matchLabels:
      app: shuttle
  policyTypes: [Egress]
  egress:
    - to:
        - ipBlock:
            cidr: 192.0.2.0/24
            except:
              - 192.0.2.128/25
      ports:
        - protocol: TCP
          port: 443
```

Apply it:

```sh
kubectl apply -f networkpolicy-shuttle-address-range.yaml
```

Then check the stored boundaries and remove this example permission:

```sh
kubectl -n starfleet describe networkpolicy shuttle-address-range
kubectl -n starfleet delete networkpolicy shuttle-address-range
```

The documentation address range is not a live server in this playground. Look for the enclosing range and exclusion in the description; this checks interpretation, not external connectivity. Every `except` range must be inside `cidr`. An `ipBlock` cannot share a peer entry with a pod or namespace selector.

An exclusion is not a global deny. A different peer, rule or policy can still allow an excluded address. Address translation around Services can also change which address a plugin sees; do not assume external-address matching has identical behavior on every cluster.

You can now read the scope of an empty selector, combine namespace and Pod labels, and distinguish a named destination port from a Service port. Those boundaries also apply to the DNS destination that an isolated client needs before it can use Service names.

## Common pitfalls

> [!WARNING]
> - **Making two peers when both selectors must match.** Keep the two selectors under one dash.
> - **Using an empty namespace selector for one namespace.** It matches every namespace.
> - **Treating `except` as a deny rule.** It only removes addresses from that one `ipBlock` allow.
> - **Naming a Service port in a policy.** A named policy port resolves on the receiving Pod, not on the Service.
