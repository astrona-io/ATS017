---
estimated_duration: 20m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-050/module-02/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Read why the pod is Pending

```bash
kubectl -n starfleet get pods -l app=scout-critical
kubectl -n starfleet get pod -l app=scout-critical -o jsonpath='{.items[0].status.conditions[?(@.type=="PodScheduled")].message}{"\n"}'
kubectl get priorityclass
```

You should see something like:

```text
NAME                              READY   STATUS    RESTARTS   AGE
scout-critical-68d96895f4-t7rvd   0/1     Pending   0          8s
0/1 nodes are available: 1 Insufficient cpu. no new claims to deallocate, preemption: 0/1 nodes are available: 1 No preemption victims found for incoming pod.
NAME                      VALUE        GLOBAL-DEFAULT   AGE   PREEMPTIONPOLICY
system-cluster-critical   2000000000   false            31s   PreemptLowerPriority
system-node-critical      2000001000   false            31s   PreemptLowerPriority
```

The node has too little CPU. The scheduler found no victim, because `scout-critical` and `probe` both have priority `0`.

## Step 2: Create a PriorityClass

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

```bash
kubectl apply -f priorityclass-platform-high.yaml
```

## Step 3: Give the class to scout-critical

The patch changes the pod template, so the Deployment creates a new pod with the new priority:

```bash
kubectl -n starfleet patch deployment scout-critical --type merge -p '{"spec":{"template":{"spec":{"priorityClassName":"platform-high"}}}}'
kubectl -n starfleet rollout status deployment/scout-critical --timeout=180s
```

## Step 4: Prove it

```bash
kubectl -n starfleet get pods -l app=scout-critical -o wide
kubectl -n outpost get pods
kubectl get events -A --field-selector reason=Preempted
```

You should see something like (the node name differs):

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

The output comes from the playground, which uses the same layout. The scheduler evicted one `probe` pod, and its replacement stays `Pending`.

## Step 5: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-050/module-02/labs/lab-01
```
