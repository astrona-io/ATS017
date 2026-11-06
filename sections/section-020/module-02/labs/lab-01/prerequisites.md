# Prerequisites

You need to select Pods and namespaces by labels, write a NetworkPolicy,
and run a bounded curl request with `kubectl exec`. Understand that an
isolated connection needs sender egress and receiver ingress permission.

Astrona supplies kubectl and the lab context on `terminal`. The node
preloads curl 8.22.0, podinfo 6.15.0 and go-httpbin 2.25.0 images. Every
Deployment has a `client` container; use `-c client` when sending requests.
The kindnet network plugin enforces the policies. No Calico installation
or additional terminal command is required.
