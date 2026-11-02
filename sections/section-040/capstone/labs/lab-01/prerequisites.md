# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that OpenCost serves an allocation API on port `9003` of the Service `opencost` in the namespace `opencost`, and that you can reach it with `kubectl get --raw` through the Kubernetes API server proxy.
- Know the query parameters `window`, `aggregate` and `filter`, and the fields `totalCost` and `totalEfficiency` in the answer.
- Know that OpenCost reads the labels of pods, not the labels of Deployments, and that `aggregate=namespace,controller` groups cost by Deployment.
- Know how to change a Deployment with `kubectl patch` or `kubectl set resources`, and how to create a ConfigMap with `kubectl create configmap --from-literal`.

The cluster is a single-node `kind` cluster running Kubernetes 1.35. Prometheus and OpenCost 1.121.3 are installed with Helm, and OpenCost uses its default on-premises prices. The costs are small dollar amounts from that price list, not a real bill.
