# PriorityClass And Preemption

When a node is full, a new pod stays `Pending`. If the new pod is more important than the pods already running, waiting is the wrong result. Kubernetes solves this with pod priority: every pod has a number, and the scheduler can remove (preempt) pods with a lower number to place a pod with a higher number. This part shows that on a full node.

## Pod priority and the PriorityClass

A PriorityClass is a cluster-wide object that maps a name to an integer `value`. A pod selects a class with `spec.priorityClassName`. The API server copies the value into `spec.priority` when it creates the pod. A pod with no class gets the value `0`, unless one class has `globalDefault: true`.

The scheduler uses the priority in two ways. It places higher-priority pods first when many pods wait. When a pod does not fit on any node, it also looks for lower-priority pods to evict. That second step is preemption.

Two built-in classes exist in every cluster. List them:

<!-- astrona:playground:renew -->

```sh
kubectl get priorityclass
```

```text
NAME                      VALUE        GLOBAL-DEFAULT   AGE   PREEMPTIONPOLICY
system-cluster-critical   2000000000   false            31s   PreemptLowerPriority
system-node-critical      2000001000   false            31s   PreemptLowerPriority
```

Kubernetes keeps these two for its own components, such as `kube-system` pods. Tenant classes use values far below them.

## A pod that does not fit

The `probe` pods in `outpost` use almost all the free CPU of the node. Check the node and the three pods:

```sh
kubectl -n outpost get pods -o wide
kubectl describe node | grep -A 6 "Allocated resources"
```

```text
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE                                            NOMINATED NODE   READINESS GATES
probe-7cbdf54c48-65f2l   1/1     Running   0          11s   10.244.0.5   astro-ats-017-playground-050-02-control-plane   <none>           <none>
probe-7cbdf54c48-lb9fn   1/1     Running   0          11s   10.244.0.7   astro-ats-017-playground-050-02-control-plane   <none>           <none>
probe-7cbdf54c48-mslx9   1/1     Running   0          11s   10.244.0.6   astro-ats-017-playground-050-02-control-plane   <none>           <none>
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests     Limits
  --------           --------     ------
  cpu                5859m (97%)  0 (0%)
  memory             402Mi (1%)   564Mi (2%)
```

The node has `97%` of its CPU requested. The numbers depend on the machine that runs `kind`, so yours differ. Now create a pod that requests `300m`. Save this as `deployment-scout-critical.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout-critical
  namespace: starfleet
  labels:
    app: scout-critical
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: scout-critical
  template:
    metadata:
      labels:
        app: scout-critical
    spec:
      containers:
        - name: scout
          image: ghcr.io/stefanprodan/podinfo:6.15.0
          resources:
            requests:
              cpu: 300m
              memory: 32Mi
            limits:
              memory: 64Mi
```

Apply it:

```sh
kubectl apply -f deployment-scout-critical.yaml
```

Then check the result. The scheduler writes why it cannot place the pod in the `PodScheduled` condition:

```sh
kubectl -n starfleet get pods -l app=scout-critical
kubectl -n starfleet get pod -l app=scout-critical -o jsonpath='{.items[0].status.conditions[?(@.type=="PodScheduled")].message}{"\n"}'
```

```text
NAME                              READY   STATUS    RESTARTS   AGE
scout-critical-68d96895f4-t7rvd   0/1     Pending   0          8s
0/1 nodes are available: 1 Insufficient cpu. no new claims to deallocate, preemption: 0/1 nodes are available: 1 No preemption victims found for incoming pod.
```

The pod is `Pending` because the node has too little CPU. The message ends with `No preemption victims found`: the scheduler tried preemption, but every other pod has the same priority `0`, so none may be evicted. Preemption needs a priority gap. The next section creates that gap.

## Create a PriorityClass and watch preemption

Save this as `priorityclass-platform-high.yaml`:

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: platform-high
value: 100000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "Platform workloads that may evict tenant batch pods."
```

Apply it:

```sh
kubectl apply -f priorityclass-platform-high.yaml
```

Then make `scout-critical` use the class. The patch changes the pod template, so the Deployment creates a new pod:

```sh
kubectl -n starfleet patch deployment scout-critical --type merge -p '{"spec":{"template":{"spec":{"priorityClassName":"platform-high"}}}}'
kubectl -n starfleet get pods -l app=scout-critical -o wide
kubectl -n outpost get pods
kubectl get events -A --field-selector reason=Preempted
```

```text
NAME                              READY   STATUS    RESTARTS   AGE   IP           NODE                                            NOMINATED NODE   READINESS GATES
scout-critical-7586797ff8-vc9zx   1/1     Running   0          13s   10.244.0.9   astro-ats-017-playground-050-02-control-plane   <none>           <none>
NAME                     READY   STATUS    RESTARTS   AGE
probe-7cbdf54c48-8zbfx   0/1     Pending   0          13s
probe-7cbdf54c48-kknzj   1/1     Running   0          23s
probe-7cbdf54c48-nc2mc   1/1     Running   0          23s
NAMESPACE   LAST SEEN   TYPE     REASON      OBJECT                       MESSAGE
outpost     13s         Normal   Preempted   pod/probe-7cbdf54c48-j7nfh   Preempted by pod c7249b5c-141f-4b77-9a0a-242518567c0d on node astro-ats-017-playground-050-02-control-plane
```

The `scout-critical` pod is now `Running`. The scheduler (kube-scheduler) evicted one `probe` pod and wrote a `Preempted` event on it. The `probe` Deployment then created a replacement, and that replacement is `Pending`, because the node is full again. The tenant lost capacity so that the higher-priority pod could run. Confirm the priority numbers:

```sh
kubectl -n starfleet get pods -l app=scout-critical -o custom-columns=NAME:.metadata.name,CLASS:.spec.priorityClassName,PRIORITY:.spec.priority
kubectl -n outpost get pod -l app=probe -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CLASS:.spec.priorityClassName,PRIORITY:.spec.priority
```

```text
NAME                              CLASS           PRIORITY
scout-critical-7586797ff8-vc9zx   platform-high   100000
NAME                     STATUS    CLASS    PRIORITY
probe-7cbdf54c48-8zbfx   Pending   <none>   0
probe-7cbdf54c48-kknzj   Running   <none>   0
probe-7cbdf54c48-nc2mc   Running   <none>   0
```

A PriorityClass gives a pod a number through `priorityClassName`, and the API server stores it in `spec.priority`. When a pod does not fit, kube-scheduler can evict pods with a lower number and writes a `Preempted` event on each victim. The open question is whether a high priority always means the right to evict. It does not, and the next part shows the field that changes it.

## Common pitfalls

> [!WARNING]
> - **Expecting preemption between equal priorities.** Pods with the same value never evict each other. The message `No preemption victims found` means no lower-priority pod exists.
> - **Setting `globalDefault: true` by accident.** Only one class may be the default, and it changes the priority of every new pod without a class. Existing pods keep their value.
> - **Forgetting that the victim loses its work.** A preempted pod is deleted, not paused. Its Deployment creates a replacement, which may stay `Pending`.
> - **Using system class values for tenants.** Values above one billion are reserved for `system-cluster-critical` and `system-node-critical`.

## Your mission: Make Room With A PriorityClass

You can now create a PriorityClass and read a preemption. The mission gives you a full node and a pod that cannot run. You choose the priority, and you must keep the other tenant's rules intact.

Pause the playground first:

```sh
astrona stop ats-017-playground-050-02
```

Start the mission and send it for grading:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-02/labs/lab-01
astrona submit -c sections/section-050/module-02/labs/lab-01
```

When you finish, remove the mission cluster and resume the playground:

```sh
astrona destroy ats-017-lab-050-02-01
astrona start ats-017-playground-050-02
```
