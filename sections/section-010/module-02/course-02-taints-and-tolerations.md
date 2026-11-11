# Taints And Tolerations

Node affinity lets a pod choose nodes. A platform team often needs the opposite: a node that refuses everybody except one tenant, for example because the tenant pays for it or because it has special hardware. That is a job for taints. This part reads the taint on the zone-b worker, gives the `outpost` tenant's `probe` a toleration, and shows that a toleration only opens the door. Moving the pods through it takes node affinity as well.

## What a taint does

A **taint** is a mark on a node with a key, an optional value and an effect. It repels pods. A **toleration** is an entry in a pod spec that matches a taint and lets the pod past it. The effect decides how strong the repelling is:

| Effect | New pods without a matching toleration | Pods already running |
| --- | --- | --- |
| `NoSchedule` | Not scheduled on the node | Stay |
| `PreferNoSchedule` | Avoided if another node fits | Stay |
| `NoExecute` | Not scheduled on the node | Evicted, unless they tolerate it |

Read the taints of all three nodes:

<!-- astrona:playground:renew -->

```sh
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

You should see something like:

```text
NAME                                            TAINTS
astro-ats-017-playground-010-02-control-plane   [map[effect:NoSchedule key:node-role.kubernetes.io/control-plane]]
astro-ats-017-playground-010-02-worker          <none>
astro-ats-017-playground-010-02-worker2         [map[effect:NoSchedule key:dedicated value:outpost]]
```

The zone-b worker has the taint `dedicated=outpost:NoSchedule`. The playground set it with `kubectl taint node <name> dedicated=outpost:NoSchedule`, and you remove a taint by repeating the command with a `-` at the end: `kubectl taint node <name> dedicated=outpost:NoSchedule-`. The control plane taint is the reason ordinary pods never run on the control plane node. `kubectl describe node` shows the same information in its `Taints:` line.

## A toleration alone

The `outpost` tenant should run on its reserved worker. Start with the obvious change: give `probe` a toleration that matches the taint exactly, and three replicas so the placement is easy to see.

Save this as `deployment-probe-tolerate.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: outpost
  labels:
    app: probe
spec:
  replicas: 3
  selector:
    matchLabels:
      app: probe
  template:
    metadata:
      labels:
        app: probe
    spec:
      tolerations:
        - key: dedicated
          operator: Equal
          value: outpost
          effect: NoSchedule
      containers:
        - name: probe
          image: mccutchen/go-httpbin:2.25.0
          ports:
            - name: http
              containerPort: 8080
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              memory: 64Mi
```

Apply it and check where the replicas run:

```sh
kubectl apply -f deployment-probe-tolerate.yaml
kubectl -n outpost get pods -l app=probe -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName
```

You should see something like (the split between the workers may differ):

```text
NAME                     STATUS    NODE
probe-7c7596d879-9t5k2   Running   astro-ats-017-playground-010-02-worker2
probe-7c7596d879-g99nq   Running   astro-ats-017-playground-010-02-worker2
probe-7c7596d879-hcgt2   Running   astro-ats-017-playground-010-02-worker
```

Some replicas landed on the reserved worker, and at least one did not. The toleration removed the taint from the filter step, so both workers are now allowed, and the scheduler spread the replicas over both. Nothing in the pod says it should prefer zone b. **A toleration permits; it never attracts.** The tenant now shares the general worker with everyone else.

The `operator: Equal` form matches one key and value. `operator: Exists` with only a `key` matches the taint whatever its value, and a toleration with `operator: Exists` and no key at all tolerates every taint, which is almost never what you want.

## Toleration plus node affinity

To dedicate a node, combine the two tools: the taint keeps everyone else off the node, and required node affinity keeps the tenant on it.

Save this as `deployment-probe-dedicated.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: outpost
  labels:
    app: probe
spec:
  replicas: 3
  selector:
    matchLabels:
      app: probe
  template:
    metadata:
      labels:
        app: probe
    spec:
      tolerations:
        - key: dedicated
          operator: Equal
          value: outpost
          effect: NoSchedule
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: topology.kubernetes.io/zone
                    operator: In
                    values:
                      - zone-b
      containers:
        - name: probe
          image: mccutchen/go-httpbin:2.25.0
          ports:
            - name: http
              containerPort: 8080
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              memory: 64Mi
```

Apply it. The Deployment rolls out new pods with the new template:

```sh
kubectl apply -f deployment-probe-dedicated.yaml
kubectl -n outpost rollout status deploy/probe
kubectl -n outpost get pods -l app=probe -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName
```

You should see something like:

```text
NAME                     STATUS    NODE
probe-668575cfd7-qtkxk   Running   astro-ats-017-playground-010-02-worker2
probe-668575cfd7-vgnw8   Running   astro-ats-017-playground-010-02-worker2
probe-668575cfd7-xd6pv   Running   astro-ats-017-playground-010-02-worker2
```

Every replica now runs on the reserved worker. The node affinity rule made the zone-a worker fail the filter, and the toleration let the pods past the taint on the zone-b worker. Together they give the tenant the node and keep everyone else off it. In production you would usually use a dedicated label such as `dedicated=outpost` for the affinity instead of the zone, so the rule still holds when the tenant gets more nodes.

## Reading a taint in a FailedScheduling message

The `scout-zone-b` pod from the node affinity examples is still `Pending`, and now you can read its message completely: `2 node(s) had untolerated taint(s)` means the pod has no toleration for the taints on two nodes. When you see that phrase, list the node taints and compare them with the pod's `tolerations` field. Either the pod needs a toleration, or it was never meant to run there and a required rule is wrong.

You can now reserve a node with a taint, let one tenant past it with a toleration, and keep that tenant on the node with node affinity. You have also seen why the toleration alone was not enough. The open question is a different kind of placement: not which node, but how the replicas of one workload are spread across nodes and zones.

## Common pitfalls

> [!WARNING]
> - **Expecting a toleration to attract pods.** It only removes a filter. Add node affinity to keep the pods on the node.
> - **Mismatching the effect.** A toleration for `NoSchedule` does not tolerate a `NoExecute` taint with the same key and value.
> - **Tolerating everything.** A toleration with `operator: Exists` and no key passes every taint, including the control plane's.
> - **Using `NoExecute` without thinking about running pods.** It evicts every pod on the node that does not tolerate it.
