# Preemption Policy Never

A high priority number does not always give a pod the right to evict others. A batch job is an example: it should come first in the scheduling queue, but it must not remove a running service to start. A PriorityClass can express this. This part shows a pod that has a high priority and still stays `Pending`.

The node in this part is almost full. The `probe` pods in `outpost` and the `scout-critical` pod, which uses the `platform-high` class, already request nearly all of its CPU.

## Preemption can be switched off

Some pods should run before others but must never evict anything. The field `preemptionPolicy` on the PriorityClass controls that. The default is `PreemptLowerPriority`. The value `Never` keeps the priority for queue order, but the scheduler does not evict pods for it.

<!-- astrona:playground:renew -->

Save this as `priorityclass-batch-patient.yaml`:

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: batch-patient
value: 50000
globalDefault: false
preemptionPolicy: Never
description: "Higher than default, but never evicts other pods."
```

Apply it:

```sh
kubectl apply -f priorityclass-batch-patient.yaml
```

Save this as `deployment-batch-patient.yaml`. It asks for `1700m` of CPU, more than is free:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-patient
  namespace: starfleet
  labels:
    app: batch-patient
spec:
  replicas: 1
  selector:
    matchLabels:
      app: batch-patient
  template:
    metadata:
      labels:
        app: batch-patient
    spec:
      priorityClassName: batch-patient
      containers:
        - name: worker
          image: mccutchen/go-httpbin:2.25.0
          resources:
            requests:
              cpu: 1700m
              memory: 32Mi
```

Apply it, then read the scheduler message of the new pod:

```sh
kubectl apply -f deployment-batch-patient.yaml
kubectl -n starfleet get pod -l app=batch-patient --field-selector status.phase=Pending -o jsonpath='{.items[0].status.conditions[?(@.type=="PodScheduled")].message}{"\n"}'
```

```text
0/1 nodes are available: 1 Insufficient cpu. no new claims to deallocate, preemption: not eligible due to preemptionPolicy=Never.
```

The pod has priority `50000`, higher than every `probe` pod, but it stays `Pending`. The message `not eligible due to preemptionPolicy=Never` names the field that blocks it. Use `1700m` only if it is larger than the free CPU on your node; pick a larger value if your node is bigger.

You now know that the priority number and the right to evict are two separate settings. A class with `preemptionPolicy: Never` moves its pods forward in the scheduling queue, but the scheduler never evicts a pod for them. The open question is who may use a high class: any pod in any namespace can name `platform-high`. A quota scope limits that.

## Common pitfalls

> [!WARNING]
> - **Expecting `Never` to lower the priority.** The pod keeps its number and its place in the queue. Only the right to evict is removed.
> - **Using a request that fits the node.** The demonstration needs a request larger than the free CPU. If the pod fits, it runs and shows nothing.
