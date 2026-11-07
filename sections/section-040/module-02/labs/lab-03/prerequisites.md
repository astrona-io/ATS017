# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that OpenCost serves an allocation API on port `9003` of the Service `opencost` in the namespace `opencost`, and that you can reach it with `kubectl get --raw` through the Kubernetes API server proxy.
- Know the query parameters `window`, `aggregate` and `filter`, and the field `totalCost` in the answer.
- Know how to read a JSON answer with `jq`, and how to sort entries with `sort_by`.
- Know how to change the replica count of a Deployment with `kubectl scale` and how to wait for the rollout with `kubectl rollout status`.

The cluster is a single-node `kind` cluster running Kubernetes 1.35 with metrics-server. Prometheus and OpenCost 1.121.3 are installed with Helm, and OpenCost uses its default on-premises prices. The costs are small dollar amounts from that price list, not a real bill.
