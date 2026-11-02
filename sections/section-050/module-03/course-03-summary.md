# Summary

A shared cluster needs rules that apply on their own: one that rejects bad requests, and one that gives every new tenant the same base objects. Kyverno does both through admission.

## What you learned

Kyverno runs as an admission webhook. A `ClusterPolicy` holds rules, and each rule matches resources by kind, namespace or label. The API server applies LimitRange defaults first, then calls the Kyverno webhook, and checks the ResourceQuota last. A request denied by Kyverno never counts against a quota.

A `validate` rule uses a `pattern` that describes a valid resource. With `failureAction: Enforce`, a request that breaks the pattern is denied, and the message names the policy, the rule and the failing path. With `failureAction: Audit`, the request passes, and the reports controller writes the result into a `PolicyReport` for each resource. Kyverno adds `autogen-` rules, so a rule on `Pod` also covers Deployments and other controllers. A policy never changes pods that already run.

A `generate` rule matches a namespace and creates other objects in it. It reads the namespace name from `{{request.object.metadata.name}}`. With `synchronize: true`, the background controller puts a deleted or edited object back. A label on the namespace decides which namespaces become tenants.

- A `validate` rule rejects, and `Audit` only reports.
- A `PolicyReport` lists pass and fail for each resource, including old ones.
- A `generate` rule gives each tenant namespace a quota and a LimitRange.
- A new or changed policy needs a few seconds before the webhook uses it.

<!-- astrona:playground:destroy -->
