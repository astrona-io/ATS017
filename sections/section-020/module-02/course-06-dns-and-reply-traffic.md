# DNS And Reply Traffic

After a default-deny egress policy, `shuttle` can fail before it even sends a request to `scout`. Domain Name System (DNS) resolution translates a Service name into an IP address. The DNS query leaves the client Pod, so it needs an egress permission separate from the application connection.

<!-- astrona:playground:renew -->

Save this as `networkpolicy-tenant-default-deny.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-default-deny
  namespace: starfleet
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress: []
  egress: []
```

Apply it:

```sh
kubectl apply -f networkpolicy-tenant-default-deny.yaml
```

Then inspect the resolver and the DNS endpoints:

```sh
kubectl -n starfleet exec deploy/shuttle -- cat /etc/resolv.conf
kubectl -n kube-system get service kube-dns -o yaml
kubectl -n kube-system get pods -l k8s-app=kube-dns --show-labels
kubectl -n starfleet exec deploy/shuttle -- curl -v --max-time 3 http://scout/version
```

Look for a `nameserver` address matching the DNS Service and ready DNS Pods with `k8s-app=kube-dns`. If an existing allow-DNS policy remains, the lookup can already succeed: a new default deny cannot override it. Without any DNS allow, expect resolution to fail or time out. No request can reach `scout` by name until resolution succeeds.

## The scoped DNS permission

In this kindnet playground, the DNS Service forwards to CoreDNS Pods in `kube-system`. CoreDNS is the DNS server that answers cluster name queries. The rule must select those Pods and allow destination port 53 over both User Datagram Protocol (UDP) and Transmission Control Protocol (TCP). TCP supports DNS exchanges that cannot complete over UDP, including fallback after a truncated response.

Save this as `networkpolicy-tenant-allow-dns.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-allow-dns
  namespace: starfleet
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

Apply it:

```sh
kubectl apply -f networkpolicy-tenant-allow-dns.yaml
```

Then check the rule and retry the request:

```sh
kubectl -n starfleet describe networkpolicy tenant-allow-dns
kubectl -n starfleet exec deploy/shuttle -- curl -v --max-time 3 http://scout/version
```

Look for address resolution followed by a connection attempt. The application request still requires egress to `scout` on its Pod port, and ingress at `scout`. If those permissions already exist, expect the application to answer. The DNS rule alone grants neither permission.

The namespace and Pod selectors share one `to` item. Splitting them would allow port 53 to every Pod in `kube-system` and every local Pod labelled `k8s-app=kube-dns`. A cluster using a node-local DNS cache needs a rule for the resolver it actually uses; this exercise has no such cache and does not claim that this rule fits every installation.

## Replies do not need reverse allows

For a new `shuttle` to `scout` connection, the plugin checks the sender's egress and receiver's ingress. Once that connection is allowed, its replies are implicitly allowed. `scout` does not need a new egress permission to send the response, and `shuttle` does not need an ingress permission for that response. The same principle lets DNS replies return to an ingress-isolated client.

A connection that `scout` initiates back to `shuttle` is different. It is a new connection, so it needs its own permissions in the opposite direction. Do not open all ingress on the client to fix replies. Also use fresh test connections after policy changes: the handling of existing connections after a policy update can vary.

You can now separate DNS egress, application egress and application ingress. With those three stages understood, a bounded request and a direct Pod-address test can locate which stage fails.

## Common pitfalls

> [!WARNING]
> - **Allowing only application ports.** A Service name still requires access to its DNS resolver.
> - **Allowing only UDP 53.** Include TCP 53 for DNS exchanges that need it.
> - **Opening reverse traffic for replies.** Responses to an allowed connection are implicitly permitted; a new reverse connection is not.
