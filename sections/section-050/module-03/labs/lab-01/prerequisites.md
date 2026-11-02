# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a Kyverno `ClusterPolicy` has `rules`, each with a `match` block and a `validate` block.
- Know that `failureAction` is `Enforce` (deny) or `Audit` (allow and report), and that a `pattern` describes a valid resource.
- Know that a new policy needs a few seconds before the Kyverno webhook uses it.

The cluster is a single-node `kind` cluster running Kubernetes 1.35 with Kyverno `v1.19.2`, installed by Helm (chart `3.9.2`). The `probe` Deployment runs go-httpbin 2.25.0.
