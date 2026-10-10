# Default Deny And How Policies Select Pods

Before you block anything, you must know what is open. On a cluster without NetworkPolicy, every pod reaches every other pod. This part proves that in the playground, then applies the most common policy of all, a default deny for incoming traffic, and shows how to find the policies that select a pod.

## Every pod reaches every pod

Send one request inside `starfleet` and one from `outpost` into `starfleet`. The `-w '%{http_code}\n'` option makes `curl` print only the HTTP status code, and `-m 3` stops it after three seconds:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://scout/version
kubectl -n outpost exec deploy/shuttle -- curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://probe.starfleet/get
```

You should see something like:

```text
200
200
```

Both requests succeed, including the one that crosses from one tenant's namespace into another's. Namespaces group objects and names; they do not separate network traffic. Only a NetworkPolicy does that.

## How a NetworkPolicy works

A NetworkPolicy has three parts. `spec.podSelector` chooses the pods in its namespace that the policy applies to; an empty selector `{}` chooses every pod in the namespace. `spec.policyTypes` lists the directions it covers: `Ingress` (traffic into the selected pods), `Egress` (traffic out of them), or both. The `ingress` and `egress` lists hold the allowed traffic.

The rules are short but strict. A pod that no policy selects for a direction is **non-isolated** in that direction: all traffic is allowed. As soon as at least one policy selects the pod for a direction, the pod is **isolated** in that direction: only traffic that some selecting policy allows gets through. Policies add up; there is no deny rule and no order. The reply to an allowed connection is always allowed, so you never write a rule for return traffic.

The policy is enforced by the network plugin on each node, not by the API server. In this playground the plugin is kindnet, the default plugin of `kind`, which enforces NetworkPolicy. A cluster whose plugin does not enforce policies accepts the objects without error and then ignores them, so always prove a policy with a real request.

## A default deny for incoming traffic

A **default-deny** policy selects every pod in a namespace and allows nothing. Its only job is to make every pod isolated, so that the other policies decide what gets in.

Save this as `networkpolicy-default-deny-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: starfleet
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Apply it:

```sh
kubectl apply -f networkpolicy-default-deny-ingress.yaml
```

Then send the same two requests again, and one from `starfleet` out to `outpost`:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://scout/version
kubectl -n outpost exec deploy/shuttle -- curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://probe.starfleet/get
kubectl -n starfleet exec deploy/shuttle -- curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://probe.outpost/get
```

You should see something like:

```text
000
command terminated with exit code 28
000
command terminated with exit code 28
200
```

The first two requests time out: `000` means `curl` got no HTTP response, and exit code 28 is `curl`'s code for a timeout. The plugin drops the packets silently, so a blocked request looks like a slow, dead server, not like a refusal. The third request still works. It goes into `outpost`, which has no policy, and leaves `starfleet` through egress, which this policy does not cover.

## Finding the policies that select a pod

When a request fails, the first question is which policies select the receiving pod. List the policies in the namespace with their pod selectors and directions:

```sh
kubectl -n starfleet get networkpolicy
kubectl -n starfleet describe networkpolicy default-deny-ingress
```

You should see something like:

```text
NAME                   POD-SELECTOR   AGE
default-deny-ingress   <none>         12s
Name:         default-deny-ingress
Namespace:    starfleet
Created on:   2026-10-10 20:15:50 +0200 CEST
Labels:       <none>
Annotations:  <none>
Spec:
  PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
  Allowing ingress traffic:
    <none> (Selected pods are isolated for ingress connectivity)
  Not affecting egress traffic
  Policy Types: Ingress
```

`POD-SELECTOR <none>` means the empty selector, so every pod in `starfleet` is selected. `kubectl describe` says it in words: the selected pods are isolated for ingress, and egress is not affected. Compare each policy's selector with the labels of the pod that does not answer (`kubectl -n starfleet get pods --show-labels`); every policy whose selector matches those labels takes part in the decision.

You can now prove what is open, isolate every pod in a namespace for incoming traffic, and read which policies select a pod. The namespace is now closed for all incoming requests. The open question is how to let exactly one flow back in.

## Common pitfalls

> [!WARNING]
> - **Expecting namespaces to isolate traffic.** Without a NetworkPolicy, every pod reaches every pod in every namespace.
> - **Reading a timeout as a broken server.** Blocked packets are dropped, so `curl` times out; check the policies before the application.
> - **Expecting an ingress policy to block egress.** `policyTypes` decides the direction; a policy with only `Ingress` leaves outgoing traffic open.
> - **Trusting a policy without a test.** A network plugin that does not enforce policies accepts them silently; prove each one with a request.
