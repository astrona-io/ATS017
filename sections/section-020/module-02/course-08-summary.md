# Summary

A NetworkPolicy turns the open network of a Kubernetes cluster into a list of allowed flows. The exercises closed one namespace in both directions on a `kind` cluster whose network plugin enforces policies, opened each needed flow again by pod labels, namespace and port, and then proved each result with a request.

## What you learned

Without any policy, every pod reaches every pod in every namespace. A NetworkPolicy selects pods in its namespace with `podSelector` and covers the directions in `policyTypes`; when `policyTypes` is omitted, every policy covers `Ingress`, and `Egress` only if an `egress` list is present. Once one policy selects a pod for a direction, the pod is isolated in that direction, and only traffic that some selecting policy allows gets through. Policies only add allowed traffic, their order does not matter, there is no deny rule, and replies to allowed connections are allowed with them. The network plugin enforces the rules, so a blocked request times out instead of being refused, and no status condition or Event reports a dropped packet.

A default-deny policy has an empty pod selector and no rules. An ingress rule lists sources in `from` and pod ports in `ports`; an egress rule lists destinations in `to`. A `podSelector` peer alone only matches pods in the policy's own namespace, a `namespaceSelector` matches whole namespaces by label, and `ipBlock` matches address ranges with an optional `except` that only shrinks that one peer. Two selectors under one dash describe one source that must match both; two dashes describe two alternatives. An empty `namespaceSelector` means every namespace, `ingress: [{}]` allows everything and `ingress: []` allows nothing.

Ports are the pod's container ports, because the Service has already changed the destination before the plugin checks the packet. A named port is resolved against the declared container ports of the receiving pod, in both ingress and egress rules. An egress default deny breaks DNS first, which shows as `Resolving timed out`; every such namespace needs an egress rule to the `kube-dns` pods in `kube-system` on port 53 over UDP and TCP, and the rule selects the pods that answer, not the Service address.

When several policies select one pod, the allowed traffic is the union of all their rules, so a narrow policy beside a broad one changes nothing until the broad one is removed. To prove a policy, test the pod address first, then the ClusterIP, then the name, and pair a successful request to a live listener with a timed-out request from a source the rules exclude.

The key facts to remember are these:

- One `from` or `to` item with a namespace selector and a pod selector means AND; two items mean OR.
- Every namespace carries `kubernetes.io/metadata.name`; select namespaces by it.
- A flow between two isolated pods needs an egress rule on the sender and an ingress rule on the receiver; the reply needs nothing.
- To diagnose, list the policies whose selector matches the pod, split by direction, and read each with `kubectl describe networkpolicy`.

<!-- astrona:playground:destroy -->
