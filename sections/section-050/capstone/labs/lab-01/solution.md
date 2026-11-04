---
estimated_duration: 45m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-050/capstone/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Look at the three problems

```bash
kubectl -n starfleet get pods
kubectl -n starfleet describe pod -l app=scout-critical
kubectl -n outpost get deploy
kubectl -n outpost describe replicaset -l app=batch-worker
```

The `scout-critical` pod is `Pending` and the scheduler event says `Insufficient cpu`. The `batch-worker` ReplicaSet reports that the quota `outpost-quota` requires memory requests and limits.

## Step 2: Create the PriorityClass and use it

Save this as `priorityclass-platform-high.yaml`:

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: platform-high
value: 100000
preemptionPolicy: PreemptLowerPriority
description: Critical platform workloads
```

Apply it, then set it on the Deployment. The Deployment uses the `Recreate` strategy, so Kubernetes stops the Pending pod and creates a new one with the priority:

```bash
kubectl apply -f priorityclass-platform-high.yaml
kubectl -n starfleet patch deploy scout-critical --type merge \
  -p '{"spec":{"template":{"spec":{"priorityClassName":"platform-high"}}}}'
kubectl -n starfleet get pods
kubectl get events -A --field-selector reason=Preempted
```

The new pod gets a `Running` status and the event list shows that the scheduler preempted a `probe` pod.

## Step 3: Set defaults with a LimitRange

Save this as `limitrange-outpost-defaults.yaml`:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: outpost-defaults
  namespace: outpost
spec:
  limits:
    - type: Container
      defaultRequest:
        memory: 32Mi
      default:
        memory: 64Mi
```

Apply it. The ReplicaSet waits between retries, so restart the Deployment to see the result at once:

```bash
kubectl apply -f limitrange-outpost-defaults.yaml
kubectl -n outpost rollout restart deploy/batch-worker
kubectl -n outpost get pods -l app=batch-worker
```

## Step 4: Keep platform-high out of outpost

A quota with the scope `PriorityClass` counts only pods of the listed classes. A limit of `0` pods blocks them. Save this as `resourcequota-outpost-no-platform-high.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: outpost-no-platform-high
  namespace: outpost
spec:
  hard:
    pods: "0"
  scopeSelector:
    matchExpressions:
      - scopeName: PriorityClass
        operator: In
        values: ["platform-high"]
```

Apply it and describe it:

```bash
kubectl apply -f resourcequota-outpost-no-platform-high.yaml
kubectl -n outpost describe resourcequota outpost-no-platform-high
```

## Step 5: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-050/capstone/labs/lab-01
```
