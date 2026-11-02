# Prerequisites

- Use `kubectl` against the lab cluster. Astrona sets `KUBECONFIG` for you.
- Know that a Kyverno `generate` rule has a `match` block and a `generate` block with `apiVersion`, `kind`, `name`, `namespace` and `data`.
- Know that `{{request.object.metadata.name}}` is the name of the namespace that triggered the rule, and that `synchronize: true` keeps the generated object in place.
- Know the ResourceQuota fields `requests.cpu`, `requests.memory`, `limits.memory` and `pods`, and the LimitRange fields `defaultRequest`, `default` and `max`.

The cluster is a single-node `kind` cluster running Kubernetes 1.35 with Kyverno `v1.19.2`, installed by Helm (chart `3.9.2`).
