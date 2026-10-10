# Overview: Isolate Traffic With NetworkPolicy (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with workloads in two namespaces and no NetworkPolicy at all, so every request succeeds at the start. There is no task, no `astrona submit` and no pass or fail. Write policies, send requests, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it. The default network plugin, kindnet, enforces NetworkPolicy.
- Namespace **`starfleet`**:

  | Workload | What it is |
  | --- | --- |
  | `scout` | `podinfo` on container port `9898`, Service `scout` on port `80` |
  | `probe` | `go-httpbin` echo server on container port `8080`, Service `probe` on port `80` |
  | `shuttle` | Client pod with `curl` |

- Namespace **`outpost`**: another `probe` (Service `probe` on port `80`) and another `shuttle`.
- Every namespace carries the label `kubernetes.io/metadata.name=<name>`. The cluster DNS pods in `kube-system` carry `k8s-app=kube-dns`.
- No NetworkPolicy exists at the start.

## Helpers

Paste these once in each new terminal. `try_request` sends one request from the `shuttle` in a namespace and prints the HTTP status code, or `000` after a three-second timeout. `list_policies` prints every policy in a namespace with its pod selector and directions.

```sh
try_request() {
  kubectl -n "$1" exec deploy/shuttle -- curl -s -m 3 -o /dev/null -w '%{http_code}\n' "$2"
}
list_policies() {
  kubectl -n "$1" get networkpolicy -o custom-columns=NAME:.metadata.name,POD-SELECTOR:.spec.podSelector.matchLabels,TYPES:.spec.policyTypes
}
```

Use them like this: `try_request starfleet http://scout/version`, `try_request outpost http://probe.starfleet/get`, `list_policies starfleet`.

## Practice tasks

- Give `outpost` its own default deny in both directions, then allow only its `shuttle` to reach `probe.starfleet` and DNS. Prove the other flows are blocked.
- Write an ingress rule for `scout` that uses a named port (`port: http`) instead of `9898`, and check that it works.
- Replace the namespace selector in a rule with `namespaceSelector: {}` and find out which pods can now reach the target.
- Add an `ipBlock` egress rule for the IP address of the `probe` pod in `outpost` (`kubectl -n outpost get pod -o wide`) and compare it with a pod selector rule.
- Delete the `allow-dns` policy and predict the exact `curl` error before you send a request.
