# Overview: Enforce Tenant Rules With Kyverno (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Kyverno installed and then waits. There is no task, no `astrona submit` and no pass or fail.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it.
- Kyverno `v1.19.2` in the namespace `kyverno` (Helm chart `3.9.2`), with the admission, background and reports controllers.
- Namespace **`starfleet`**: `scout` and `shuttle`.
- Namespace **`outpost`**: `scout`, `shuttle` and `probe`, which declares no resources.
- No Kyverno policy, no ResourceQuota and no LimitRange.

## Practice tasks

- Write a `ClusterPolicy` that rejects pods in `outpost` without CPU and memory requests and a memory limit. Create a bare pod and read the message.
- Switch the policy to `Audit` and read the `PolicyReport`. Find the existing `probe` pod in it.
- Create a Deployment without resources and read the `autogen-` rule in the rejection.
- Write a `generate` rule that creates a ResourceQuota and a LimitRange in every namespace with the label `tenant: "true"`.
- Delete the generated quota and watch Kyverno create it again.
