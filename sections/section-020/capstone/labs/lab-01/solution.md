# Solution Walkthrough

You build four things in order: the Gateway and route, the claim for `scout`, the NetworkPolicies, and a final check. Create the policies last, so you can test the route and the storage before traffic is restricted.

---

## Step 1: Gateway and route

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
```

Save this as `httproute-starfleet-routes.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: starfleet-routes
  namespace: starfleet
spec:
  parentRefs:
    - name: starfleet-gateway
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

Apply both and check:

```sh
kubectl apply -f gateway-starfleet.yaml
kubectl apply -f httproute-starfleet-routes.yaml
kubectl -n starfleet get gateway,httproute
GATEWAY=$(kubectl -n starfleet get gateway starfleet-gateway -o jsonpath='{.status.addresses[0].value}')
kubectl -n outpost exec deploy/shuttle -- curl -s http://$GATEWAY/api/info
kubectl -n outpost exec deploy/shuttle -- curl -s http://$GATEWAY/
```

The Gateway is `PROGRAMMED True`. The first request prints the JSON answer of `scout` and the second prints `bridge front end`.

## Step 2: Storage for scout

Save this as `persistentvolumeclaim-scout-data.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: scout-data
  namespace: starfleet
spec:
  storageClassName: standard-retain
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 64Mi
```

Apply it, then add the volume and the mount to the Deployment:

```sh
kubectl apply -f persistentvolumeclaim-scout-data.yaml
kubectl -n starfleet patch deploy scout --type=json -p '[
  {"op":"add","path":"/spec/template/spec/volumes","value":[{"name":"data","persistentVolumeClaim":{"claimName":"scout-data"}}]},
  {"op":"add","path":"/spec/template/spec/containers/0/volumeMounts","value":[{"name":"data","mountPath":"/data"}]}
]'
kubectl -n starfleet rollout status deploy/scout --timeout=180s
kubectl -n starfleet get pvc scout-data
```

The claim is `Bound` once the new pod runs, because `standard-retain` waits for a consumer.

## Step 3: NetworkPolicies

The Gateway's proxy pods run in the namespace `envoy-gateway-system`. Policy ports are pod ports, so allow `80` (`bridge`) and `9898` (`scout`), not the Service port.

Save this as `networkpolicy-default-deny-all.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: starfleet
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

Save this as `networkpolicy-allow-dns.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
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

Save this as `networkpolicy-allow-from-gateway.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-gateway
  namespace: starfleet
spec:
  podSelector:
    matchExpressions:
      - key: app
        operator: In
        values: [bridge, scout]
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: envoy-gateway-system
      ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 9898
```

Apply all three:

```sh
kubectl apply -f networkpolicy-default-deny-all.yaml
kubectl apply -f networkpolicy-allow-dns.yaml
kubectl apply -f networkpolicy-allow-from-gateway.yaml
```

## Step 4: Check and submit

```sh
kubectl -n outpost exec deploy/shuttle -- curl -s http://$GATEWAY/api/info
kubectl -n outpost exec deploy/shuttle -- curl -s --max-time 5 http://scout.starfleet.svc; echo "exit $?"
kubectl -n starfleet exec deploy/shuttle -- nslookup scout.starfleet.svc.cluster.local
astrona submit -c sections/section-020/capstone/labs/lab-01
```

The Gateway request still works, the direct request times out (`curl` exit `28`), and the DNS lookup resolves.

## Why the other fixes fail

- **Allowing ingress from `0.0.0.0/0` or from every namespace.** The direct request from `outpost` then succeeds, and the grader requires it to time out.
- **Allowing port `80` for `scout`.** Policy ports are pod ports, so the Gateway request to `scout` times out until port `9898` is allowed.
- **Skipping the DNS rule.** Names stop resolving in `starfleet` after the default deny.
- **Using `standard` for the claim.** The volume has the `Delete` policy and the grader requires `Retain`.
