# Generate Rules For New Tenants

A quota and a LimitRange only work in a namespace that has them. When a platform team adds a tenant, someone must remember to create both objects, with the right numbers. A Kyverno `generate` rule removes that step: when a namespace with a tenant label appears, Kyverno creates the quota and the LimitRange itself. This part writes the rule and watches it create, and re-create, the objects.

## How a generate rule works

A `generate` rule has two halves. The `match` block says which resource triggers the rule, here a `Namespace` that has the label `tenant: "true"`. The `generate` block describes the object to create: its `apiVersion`, `kind`, `name`, `namespace` and the content under `data`. The namespace can use a variable, `"{{request.object.metadata.name}}"`, which is the name of the namespace that triggered the rule.

The field `synchronize: true` ties the generated object to the policy. If someone changes or deletes the object, Kyverno puts it back. The background controller does this work, not the admission controller.

## Write the policy

<!-- astrona:playground:renew -->

The policy below has two rules, one for the ResourceQuota and one for the LimitRange. Save this as `clusterpolicy-tenant-defaults.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-defaults
spec:
  rules:
    - name: generate-resourcequota
      match:
        any:
          - resources:
              kinds: ["Namespace"]
              selector:
                matchLabels:
                  tenant: "true"
      generate:
        apiVersion: v1
        kind: ResourceQuota
        name: tenant-quota
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          spec:
            hard:
              requests.cpu: 200m
              requests.memory: 256Mi
              limits.memory: 512Mi
              pods: "10"
    - name: generate-limitrange
      match:
        any:
          - resources:
              kinds: ["Namespace"]
              selector:
                matchLabels:
                  tenant: "true"
      generate:
        apiVersion: v1
        kind: LimitRange
        name: tenant-defaults
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          spec:
            limits:
              - type: Container
                defaultRequest:
                  cpu: 25m
                  memory: 32Mi
                default:
                  memory: 64Mi
                max:
                  memory: 128Mi
```

Apply it:

```sh
kubectl apply -f clusterpolicy-tenant-defaults.yaml
kubectl get clusterpolicy
```

```text
clusterpolicy.kyverno.io/tenant-defaults created
NAME                      ADMISSION   BACKGROUND   READY   AGE   MESSAGE
require-requests-limits   true        true         True    61s   Ready
tenant-defaults           true        true         True    5s    Ready
```

The list also shows any other policy you created, such as `require-requests-limits`.

## Create two namespaces

Save a namespace with the tenant label as `namespace-tenant-a.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a
  labels:
    tenant: "true"
```

Save a namespace without the label as `namespace-tenant-b.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-b
```

Apply both, wait a few seconds, and look in each namespace:

```sh
kubectl apply -f namespace-tenant-a.yaml
kubectl apply -f namespace-tenant-b.yaml
kubectl -n tenant-a get resourcequota,limitrange
kubectl -n tenant-b get resourcequota,limitrange
```

```text
namespace/tenant-a created
namespace/tenant-b created
NAME                         REQUEST                                                      LIMIT                    AGE
resourcequota/tenant-quota   pods: 0/10, requests.cpu: 0/200m, requests.memory: 0/256Mi   limits.memory: 0/512Mi   8s

NAME                         CREATED AT
limitrange/tenant-defaults   2026-11-02T03:27:00Z
No resources found in tenant-b namespace.
```

The namespace `tenant-a` has the generated quota and LimitRange. The namespace `tenant-b` has neither, because it has no `tenant` label, so the rule did not match. The label is the switch that decides which namespaces are tenants.

## Synchronize keeps the objects in place

Delete the generated quota. The background controller notices and creates it again:

```sh
kubectl -n tenant-a delete resourcequota tenant-quota
kubectl -n tenant-a get resourcequota
```

```text
resourcequota "tenant-quota" deleted from tenant-a namespace
NAME           REQUEST                                                      LIMIT                    AGE
tenant-quota   pods: 0/10, requests.cpu: 0/200m, requests.memory: 0/256Mi   limits.memory: 0/512Mi   8s
```

The `AGE` of `8s` shows a new object. The tenant cannot remove its own quota. Now create a pod with no resources in `tenant-a`. The generated LimitRange gives it defaults, and the quota counts them:

```sh
kubectl -n tenant-a run bare --image=mccutchen/go-httpbin:2.25.0
kubectl -n tenant-a get pod bare -o jsonpath='{.spec.containers[0].resources}{"\n"}'
kubectl -n tenant-a describe resourcequota tenant-quota
```

```text
pod/bare created
{"limits":{"memory":"64Mi"},"requests":{"cpu":"25m","memory":"32Mi"}}
Name:            tenant-quota
Namespace:       tenant-a
Resource         Used  Hard
--------         ----  ----
limits.memory    64Mi  512Mi
pods             1     10
requests.cpu     25m   200m
requests.memory  32Mi  256Mi
```

The pod is accepted with a `25m` CPU request, a `32Mi` memory request and a `64Mi` memory limit. All three come from the generated LimitRange, and `used` in the quota shows them. A validate rule that requires resources would also accept this pod in a tenant namespace, because the LimitRange fills the resources in before Kyverno checks the pod.

## What you know now

A `generate` rule matches a namespace by label and creates other objects in it. With `synchronize: true`, the background controller keeps those objects in place. A tenant namespace therefore starts with a ResourceQuota that caps it and a LimitRange that gives its pods defaults, and no person has to create them. A namespace without the label gets nothing. Together with the validate rule, the platform team can both reject bad pods and give every tenant the same base rules.

## Common pitfalls

> [!WARNING]
> - **Forgetting the label.** A namespace without `tenant: "true"` gets no quota and no LimitRange. The rule does not warn about it.
> - **Expecting `generate` to change old namespaces.** The rule runs when a matching namespace is created or updated. Add the label to an existing namespace to trigger it.
> - **Editing the generated quota.** With `synchronize: true`, Kyverno reverts the change. Edit the policy instead.
> - **Using `data` and `clone` together.** A generate rule creates content from `data` or copies an object with `clone`. Use one of them.

## Your mission: Generate Tenant Defaults With Kyverno

You can now write a `generate` rule that gives each tenant namespace a quota and a LimitRange. The mission asks for a policy that does this for namespaces with a tenant label, and nothing for others.

Pause the playground first:

```sh
astrona stop ats-017-playground-050-03
```

Start the mission and send it for grading:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-03/labs/lab-02
astrona submit -c sections/section-050/module-03/labs/lab-02
```

When you finish, remove the mission cluster and resume the playground:

```sh
astrona destroy ats-017-lab-050-03-02
astrona start ats-017-playground-050-03
```
