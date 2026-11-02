# Enforce Tenant Rules With Kyverno

A ResourceQuota and a LimitRange bound a namespace, but both are objects someone must create and keep in step with every new namespace. They also cannot say "reject every pod that has no memory limit" for a whole class of namespaces. A policy engine closes that gap. Kyverno is a policy engine for Kubernetes: it receives every create and update request from the API server and can reject a request, or create other objects when a namespace appears. This module teaches the two jobs the exam asks of Kyverno for tenants: a `validate` rule and a `generate` rule.

The key sentence of this module: **a Kyverno `validate` rule rejects requests that break a tenant rule, and a `generate` rule creates the quota and defaults every new tenant namespace needs.**

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-03/playground
> ```

## Learning objectives

- Explain what an admission policy adds to a ResourceQuota and a LimitRange
- Write a Kyverno `ClusterPolicy` that rejects pods without CPU and memory requests and a memory limit, and read the rejection message
- Switch a policy between `Enforce` and `Audit` with `failureAction`, and read the `PolicyReport`
- Write a Kyverno `generate` rule that creates a ResourceQuota and a LimitRange in every new namespace with a tenant label

## Before you start

You should know what a ResourceQuota and a LimitRange do. The playground has one `kind` node with Kyverno installed by Helm (chart `3.9.2`, Kyverno `v1.19.2`) and the namespaces `starfleet` and `outpost`. `outpost` runs `scout`, `shuttle` and `probe`. No Kyverno policy exists yet. The Helm install is plumbing: the module does not teach it.

## What comes next

The first part writes a `validate` rule, enforces it, and then watches the same rule in audit mode. The second part writes a `generate` rule, so that every new tenant namespace gets its quota and its defaults without a person creating them.
