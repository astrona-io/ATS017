# Node Capacity And Pending Pods

The scheduler places a pod only on a node with enough unreserved room for its requests. When no node has that room, the pod stays `Pending`, and nothing else happens: no error on the Deployment, no crash, no log line from the application. This part reads how much room a node offers and how much is already reserved. Then it creates a pod that fits nowhere and reads the scheduler's explanation.

## Capacity and allocatable

Every node reports two sets of numbers. **Capacity** is everything the node has. **Allocatable** is what is left for pods after the node reserves some for the operating system and the kubelet. The scheduler only ever compares requests with allocatable.

<!-- astrona:playground:renew -->

```sh
kubectl describe nodes | sed -n '/^Capacity:/,/^System Info:/p'
```

You should see something like this (your numbers depend on the machine that runs the playground):

```text
Capacity:
  cpu:                6
  ephemeral-storage:  104266732Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  hugepages-32Mi:     0
  hugepages-64Ki:     0
  memory:             10142776Ki
  pods:               110
Allocatable:
  cpu:                6
  ephemeral-storage:  104266732Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  hugepages-32Mi:     0
  hugepages-64Ki:     0
  memory:             10142776Ki
  pods:               110
System Info:
```

On a `kind` node the two sets are equal, because the node reserves nothing. On a production node, allocatable is usually a few hundred millicores and some memory lower than capacity, set by the kubelet's `kube-reserved`, `system-reserved` and eviction threshold settings. Plan with allocatable, never with capacity. The `pods: 110` line is a limit too: a node accepts at most 110 pods, whatever their size.

## What is already reserved

The same command, further down, shows every pod on the node with its requests and limits, and then the totals:

```sh
kubectl describe nodes | sed -n '/^Allocated resources:/,/^Events:/p'
```

You should see something like:

```text
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests     Limits
  --------           --------     ------
  cpu                1460m (24%)  800m (13%)
  memory             794Mi (8%)   884Mi (8%)
  ephemeral-storage  0 (0%)       0 (0%)
  hugepages-1Gi      0 (0%)       0 (0%)
  hugepages-2Mi      0 (0%)       0 (0%)
  hugepages-32Mi     0 (0%)       0 (0%)
  hugepages-64Ki     0 (0%)       0 (0%)
Events:
```

The `Requests` column is the sum of the requests of every pod on the node, as a share of allocatable. This is the number the scheduler works with: `1460m` of `6` CPUs are reserved, so a new pod may request up to about `4540m`. The `Limits` column may go over 100 percent; Kubernetes allows that, and the note at the top says so. The section just above it, `Non-terminated Pods`, lists the requests of each pod, so you can see who reserved what.

Real usage is a different number. `kubectl top node` shows it:

```sh
kubectl top node
```

You should see something like:

```text
NAME                                            CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
astro-ats-017-playground-010-01-control-plane   292m         4%       1025Mi          10%
```

The node reserves `1460m` of CPU but uses only `292m`. That gap is normal, and it is also money: reserved but unused capacity is what right-sizing tries to win back.

## A pod that fits nowhere

Now ask for more memory than the node has. The Deployment below requests `64Gi`.

Save this as `deployment-scout-oversized.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout-oversized
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scout-oversized
  template:
    metadata:
      labels:
        app: scout-oversized
    spec:
      containers:
        - name: scout
          image: ghcr.io/stefanprodan/podinfo:6.15.0
          resources:
            requests:
              cpu: 100m
              memory: 64Gi
```

Apply it:

```sh
kubectl apply -f deployment-scout-oversized.yaml
```

Then check the pod:

```sh
kubectl -n starfleet get pods -l app=scout-oversized
```

You should see something like:

```text
NAME                               READY   STATUS    RESTARTS   AGE
scout-oversized-8669fd5d68-wsk2l   0/1     Pending   0          5s
```

The Deployment was accepted and its ReplicaSet created the pod, but no node was assigned. The scheduler explains why in an event on the pod:

```sh
kubectl -n starfleet describe pod -l app=scout-oversized | sed -n '/^Events:/,$p'
```

You should see:

```text
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  5s    default-scheduler  0/1 nodes are available: 1 Insufficient memory. no new claims to deallocate, preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
```

Read the message from left to right. `0/1 nodes are available` says no node passed. `1 Insufficient memory` says why, with a count of nodes per reason; on a bigger cluster you see a list such as `2 Insufficient cpu, 3 node(s) had untolerated taint`. The `preemption` part says that removing lower-priority pods would not help either, because no node could ever hold `64Gi`. To see every `FailedScheduling` event in a namespace at once, filter the events by reason:

```sh
kubectl -n starfleet get events --field-selector reason=FailedScheduling
```

The fix is always on the requests or on the cluster: lower the request to a value that fits allocatable, or add a node that is large enough. Delete the Deployment when you are done:

```sh
kubectl -n starfleet delete deployment scout-oversized
```

You can now read a node's allocatable capacity, see how much of it is already reserved by requests, and explain a `Pending` pod from its `FailedScheduling` event. Together with limits and QoS classes, that covers everything Kubernetes does with the `resources` block of a single pod.

## Common pitfalls

> [!WARNING]
> - **Comparing requests with `kubectl top`.** The scheduler ignores real usage; compare requests with allocatable and the `Requests` column of `kubectl describe node`.
> - **Looking at the Deployment for the reason.** It shows `0/1` ready and nothing else. The reason is a `FailedScheduling` event on the pod.
> - **Planning with capacity.** Production nodes reserve part of their capacity; only allocatable is available to pods.
> - **Forgetting the pod count limit.** A node with free CPU and memory still rejects pods once it runs its maximum number of pods.
