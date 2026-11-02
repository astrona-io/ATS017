# Quota Scopes Limit Each Kind Of Pod

A PriorityClass is open to everyone: any pod in any namespace can name `platform-high`. A tenant that does this for every pod would evict the pods of all other tenants. A ResourceQuota with a scope solves this. A scope makes the quota count only some pods, so the namespace gets a separate budget for each kind of pod.

## Scopes and scopeSelector

A quota scope is a filter on a ResourceQuota. The quota counts a pod only if the pod matches the scope. Three scopes matter here:

- `PriorityClass` matches pods by the name of their PriorityClass. It needs a `scopeSelector`, because the quota must say which class names it counts.
- `BestEffort` matches pods that declare no requests and no limits. A quota with this scope can only limit the `pods` count, because such pods have no resources to count.
- `Terminating` matches pods that have `spec.activeDeadlineSeconds` set, for example Jobs with a deadline. `NotTerminating` matches the others.

The simple form is a list under `scopes`. The `scopeSelector` form gives an operator (`In`, `NotIn`, `Exists`, `DoesNotExist`) and values, and is the only way to select a PriorityClass by name.

## Limit high-priority pods in a namespace

The commands below need the `platform-high` PriorityClass with value `100000`. The quota below lets `outpost` run one pod of that class. Save this as `resourcequota-outpost-high.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: outpost-high
  namespace: outpost
spec:
  hard:
    pods: "1"
  scopeSelector:
    matchExpressions:
      - scopeName: PriorityClass
        operator: In
        values: ["platform-high"]
```

Apply it:

```sh
kubectl apply -f resourcequota-outpost-high.yaml
```

Now create two pods in `outpost` that use the class. Save this as `pod-high-1.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: high-1
  namespace: outpost
spec:
  priorityClassName: platform-high
  containers:
    - name: probe
      image: mccutchen/go-httpbin:2.25.0
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
```

Save a second file, `pod-high-2.yaml`, with the same content and the name `high-2`. Apply both:

```sh
kubectl apply -f pod-high-1.yaml
kubectl apply -f pod-high-2.yaml
```

```text
pod/high-1 created
Error from server (Forbidden): error when creating "pod-high-2.yaml": pods "high-2" is forbidden: exceeded quota: outpost-high, requested: pods=1, used: pods=1, limited: pods=1
```

The first pod is accepted. The second pod is rejected with the usual `exceeded quota` message, but only because both pods name `platform-high`. A pod with no class does not count against this quota. The tenant keeps its normal budget for ordinary pods and gets exactly one slot for the high class.

## Block BestEffort pods

A pod with no requests and no limits has the `BestEffort` QoS class. It is the first pod the kubelet evicts under node pressure, and it hides real usage from the scheduler. A quota with `pods: "0"` and the scope `BestEffort` forbids them. Save this as `resourcequota-outpost-besteffort.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: outpost-no-besteffort
  namespace: outpost
spec:
  hard:
    pods: "0"
  scopes: ["BestEffort"]
```

Apply it:

```sh
kubectl apply -f resourcequota-outpost-besteffort.yaml
```

Save this pod as `pod-besteffort.yaml`. It declares no resources:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-resources
  namespace: outpost
spec:
  containers:
    - name: probe
      image: mccutchen/go-httpbin:2.25.0
```

Apply it, then read both quotas:

```sh
kubectl apply -f pod-besteffort.yaml
kubectl -n outpost describe resourcequota outpost-high outpost-no-besteffort
```

```text
Error from server (Forbidden): error when creating "pod-besteffort.yaml": pods "no-resources" is forbidden: exceeded quota: outpost-no-besteffort, requested: pods=1, used: pods=0, limited: pods=0
Name:       outpost-high
Namespace:  outpost
Resource    Used  Hard
--------    ----  ----
pods        1     1


Name:       outpost-no-besteffort
Namespace:  outpost
Scopes:     BestEffort
 * Matches all pods that do not have resource requirements set. These pods have a best effort quality of service.
Resource  Used  Hard
--------  ----  ----
pods      0     0
```

The `describe` output shows the scope and a plain-language note on what it matches. Both quotas can exist in the same namespace. The API server checks every quota that matches the pod, and the pod must pass all of them.

## What you know now

A scope turns one ResourceQuota into a budget for one kind of pod. The `PriorityClass` scope with a `scopeSelector` limits how many pods may use a class. The `BestEffort` scope with `pods: "0"` forbids pods without resources. Together with PriorityClasses, these objects let a platform team give every tenant a fair share and keep the high classes for the pods that need them.

## Common pitfalls

> [!WARNING]
> - **A `PriorityClass` scope without a `scopeSelector`.** The API server rejects it, because the quota needs the class names.
> - **Counting resources in a `BestEffort` quota.** The scope allows only the `pods` resource. Pods without resources have nothing else to count.
> - **Thinking the class quota limits ordinary pods.** A pod without the class is outside the scope and uses only the other quotas of the namespace.
> - **Reading `used` for a pod that is not created yet.** Quota counts only objects the API server accepted. A rejected pod never raises `used`.

## Your mission: Limit High-Priority Pods With A Quota Scope

You can now limit pods by class and by QoS with a scoped quota. The mission gives you a namespace where one tenant uses a high class for many pods. You add the scoped quota and prove that the limit holds without touching ordinary pods.

Pause the playground first:

```sh
astrona stop ats-017-playground-050-02
```

Start the mission and send it for grading:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-02/labs/lab-02
astrona submit -c sections/section-050/module-02/labs/lab-02
```

When you finish, remove the mission cluster and resume the playground:

```sh
astrona destroy ats-017-lab-050-02-02
astrona start ats-017-playground-050-02
```
