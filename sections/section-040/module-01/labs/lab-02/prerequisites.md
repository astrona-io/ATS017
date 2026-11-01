# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that OpenCost serves an allocation API on port `9003` of the Service `opencost` in the namespace `opencost`, and that you can reach it with `kubectl get --raw` through the Kubernetes API server proxy.
- Know the query parameters `window` and `aggregate`, and that `aggregate=namespace,controller` groups the answer by Deployment.
- Know that `cpuEfficiency`, `ramEfficiency` and `totalEfficiency` compare usage with the request.

The cluster is a single-node `kind` cluster running Kubernetes 1.35. Prometheus and OpenCost 1.121.3 are installed with Helm, and OpenCost uses its default on-premises prices.
