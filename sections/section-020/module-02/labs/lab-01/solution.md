# Solution Walkthrough

A NetworkPolicy lists allowed connections for selected Pods. Isolate every
Pod in `starfleet`, repair the monitoring peer, then add DNS and the one
application flow. Each Deployment's `client` container runs curl. TCP means Transmission
Control Protocol; UDP means User Datagram Protocol.

| Goal | Object and field |
| --- | --- |
| Isolate both directions | Empty `podSelector`, both `policyTypes`, no rules |
| Match both identities | One peer with namespace and Pod selectors |
| Resolve Service names | Egress to CoreDNS on UDP and TCP 53 |
| Permit the application | Sender egress and receiver ingress on TCP 8080 |

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-02/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Inspect the broad permission

```sh
kubectl get namespaces --show-labels
kubectl -n starfleet get pods --show-labels
kubectl -n starfleet describe networkpolicy allow-monitoring
kubectl -n outpost get pods --show-labels
```

Look for two separate sources in `from`. They allow every Pod in a
monitoring namespace OR local Pods with `app: shuttle`. The task needs
both labels together. No checks pass yet in the watch terminal.

## Step 2: Isolate and repair monitoring

Save this as `networkpolicy-default-deny.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: starfleet
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress: []
  egress: []
```

Apply it:

```sh
kubectl apply -f networkpolicy-default-deny.yaml
```

`podSelector: {}` selects every tenant Pod. `policyTypes` isolates ingress and egress separately. The empty lists grant no permissions; other policies can still add them.

Save this as `networkpolicy-allow-monitoring.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: starfleet
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
      podSelector:
        matchLabels:
          app: shuttle
    ports:
    - protocol: TCP
      port: 9898
```

Apply it:

```sh
kubectl apply -f networkpolicy-allow-monitoring.yaml
```

Both selectors sit in one `from` item, so both must match. `purpose` labels the Namespace, while `app` labels the Pod. The empty top-level selector protects every tenant Pod, and `ports` limits this allow to TCP 9898. Replacing the existing object removes its broad permission; adding a new narrow object beside it would leave the fault.

Then read the corrected rule and live backend address:

```sh
kubectl -n starfleet describe networkpolicy allow-monitoring
kubectl -n starfleet get pods -l app=probe -o wide
```

Copy the backend Pod address into `<PROBE_IP>`. Compare an allowed
monitoring request with a wrong Pod in the same namespace:

```sh
kubectl -n outpost exec deploy/shuttle -c client -- curl -fsS --max-time 3 http://<PROBE_IP>:9898/metrics
kubectl -n outpost exec deploy/drifter -c client -- curl -fsS --max-time 3 http://<PROBE_IP>:9898/metrics
```

Look for metrics from the approved source and a timeout from `drifter`.
The watch terminal should show **isolation** and **monitoring** passing.
It tests all three tenant Pods and also rejects a matching Pod label in
`relay`. DNS and frontend access still need their own permissions.

## Step 3: Restore DNS

Save this as `networkpolicy-allow-dns.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: starfleet
spec:
  podSelector: {}
  policyTypes:
  - Egress
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
kubectl apply -f networkpolicy-allow-dns.yaml
```

Domain Name System (DNS) translates names into addresses. The combined `to` peer selects CoreDNS Pods only in `kube-system`. The two port entries allow UDP and TCP 53. The empty top-level selector gives every tenant Pod this egress permission. Replies need no reverse ingress allow.

Then check resolution from a workload that has no application permission:

```sh
kubectl -n starfleet exec deploy/drifter -c client -- curl -v --connect-timeout 2 --max-time 3 http://probe.starfleet.svc.cluster.local/get
```

Look for successful name resolution and an attempted connection, followed
by a timeout. Resolution works, while the connection is still denied.
The watch terminal should show **dns** passing as well as **isolation**
and **monitoring**. The DNS check observes resolution from every tenant
workload and inspects both protocol permissions.

## Step 4: Allow frontend to backend

Save this as `networkpolicy-allow-frontend.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: starfleet
spec:
  podSelector:
    matchLabels:
      app: probe
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: shuttle
    ports:
    - protocol: TCP
      port: 8080
```

Apply it:

```sh
kubectl apply -f networkpolicy-allow-frontend.yaml
```

The receiver selector chooses `probe`. The local source selector chooses only `shuttle` Pods in `starfleet`. The ingress rule allows TCP 8080, the backend Pod port.

Save this as `networkpolicy-frontend-egress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
  namespace: starfleet
spec:
  podSelector:
    matchLabels:
      app: shuttle
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: probe
    ports:
    - protocol: TCP
      port: 8080
```

Apply it:

```sh
kubectl apply -f networkpolicy-frontend-egress.yaml
```

The sender selector chooses `shuttle`. Its local destination selector chooses only `probe`, on TCP 8080. The separate DNS allow still applies. The backend can send replies without an additional egress rule.

Then compare the Service path with the denied direct port:

```sh
kubectl -n starfleet exec deploy/shuttle -c client -- curl -fsS --max-time 3 http://probe/get
kubectl -n starfleet exec deploy/shuttle -c client -- curl -fsS --max-time 3 http://<PROBE_IP>:9898/metrics
kubectl -n starfleet exec deploy/drifter -c client -- curl -fsS --max-time 3 http://<PROBE_IP>:8080/get
```

Look for the backend response on the first request and timeouts on the
other two. The second request uses a real metrics listener, so its failure
can demonstrate filtering. The watch terminal should show **frontend**
passing too. All four checks should now pass after policy reconciliation.

## Step 5: Submit

Stop the watch command with Ctrl+C. Submit once from the host terminal to
record the result and finish the attempt:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-02/labs/lab-01
```

## If a check stays red

- **isolation:** Keep the empty namespace-wide `default-deny` in both
  directions. Remove unintended allows rather than adding another deny.
- **dns:** Keep namespace and Pod selectors together, and include both
  UDP and TCP 53. Resolution is separate from application access.
- **frontend:** Allow TCP 8080 at both endpoints. Service port 80 forwards
  to the backend Pod port; do not open the metrics port to the frontend.
- **monitoring:** Replace the existing broad policy. Require the Namespace
  label and Pod label in one peer. Inspect every policy that selects the
  target, and keep its live metrics listener running.
