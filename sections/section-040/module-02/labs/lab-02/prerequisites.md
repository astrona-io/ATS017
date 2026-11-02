# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that OpenCost serves an allocation API on port `9003` of the Service `opencost` in the namespace `opencost`, and that you can reach it with `kubectl get --raw` through the Kubernetes API server proxy.
- Know the query parameters `window` and `aggregate`, and the fields `totalCost` and `totalEfficiency` in the answer.
- Know how to read usage with `kubectl top pods` and requests with `kubectl get pods -o custom-columns` or `kubectl describe`.
- Know how to change requests with `kubectl set resources` or `kubectl edit`.

The cluster is a single-node `kind` cluster running Kubernetes 1.35 with metrics-server. Prometheus and OpenCost 1.121.3 are installed with Helm, and OpenCost uses its default on-premises prices. The costs are small dollar amounts from that price list, not a real bill.
