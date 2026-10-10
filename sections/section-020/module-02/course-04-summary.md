# Summary

A NetworkPolicy turns the open network of a Kubernetes cluster into a list of allowed flows. This module closed one namespace in both directions on a `kind` cluster whose network plugin enforces policies, and then opened each needed flow again by pod labels, namespace and port.

## What you learned

Without any policy, every pod reaches every pod in every namespace. A NetworkPolicy selects pods in its namespace with `podSelector` and covers the directions in `policyTypes`. Once one policy selects a pod for a direction, the pod is isolated in that direction, and only traffic that some policy allows gets through. Policies only add allowed traffic, their order does not matter, and replies to allowed connections are always allowed. The network plugin enforces them, so a blocked request times out instead of being refused.

A default-deny policy has an empty pod selector and no rules. An ingress rule lists sources in `from` and pod ports in `ports`; an egress rule lists destinations in `to`. A `podSelector` source only matches pods in the policy's own namespace, a `namespaceSelector` matches whole namespaces by label, and `ipBlock` matches address ranges. Ports are the pod's container ports, because the Service has already changed the destination before the plugin checks the packet.

An egress default deny breaks DNS first, which shows as `Resolving timed out`. Every such namespace needs an egress rule to the `kube-dns` pods in `kube-system` on port 53 over UDP and TCP. The key facts to remember are these:

- One `from` or `to` item with a namespace selector and a pod selector means AND; two items mean OR.
- Every namespace carries `kubernetes.io/metadata.name`; select namespaces by it.
- A flow between two isolated pods needs an egress rule on the sender and an ingress rule on the receiver.
- To diagnose, list the policies whose selector matches the pod, split by direction, and check each with `kubectl describe networkpolicy`.

<!-- astrona:playground:destroy -->
