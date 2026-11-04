---
estimated_duration: 20m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-050/module-02/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Look at the namespace

```bash
kubectl -n outpost get pods -o custom-columns=NAME:.metadata.name,CLASS:.spec.priorityClassName
kubectl -n outpost get resourcequota
```

You should see two pods with the class `platform-high` and no quota. The second command prints `No resources found in outpost namespace.`

## Step 2: Choose the scopes

A quota with `pods: "2"` and no scope would count every pod, so it would reject ordinary pods. The scope `PriorityClass` with a `scopeSelector` counts only pods of `platform-high`. The scope `BestEffort` with `pods: "0"` rejects pods without resources.

## Step 3: Create the quotas

Save this as `resourcequota-outpost-high.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: outpost-high
  namespace: outpost
spec:
  hard:
    pods: "2"
  scopeSelector:
    matchExpressions:
      - scopeName: PriorityClass
        operator: In
        values: ["platform-high"]
```

Apply it:

```bash
kubectl apply -f resourcequota-outpost-high.yaml
```

Save this as `resourcequota-outpost-besteffort.yaml`:

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

```bash
kubectl apply -f resourcequota-outpost-besteffort.yaml
```

## Step 4: Prove it

The quota controller needs a moment to count the existing pods. Read the quotas:

```bash
kubectl -n outpost describe resourcequota outpost-high outpost-no-besteffort
```

`outpost-high` should show `pods 2 2` and `outpost-no-besteffort` should show `pods 0 0`. Then create a third `platform-high` pod and read the rejection. Save this as `pod-high-3.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: high-3
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

```bash
kubectl apply -f pod-high-3.yaml
```

You should see an error like:

```text
Error from server (Forbidden): error when creating "pod-high-3.yaml": pods "high-3" is forbidden: exceeded quota: outpost-high, requested: pods=1, used: pods=2, limited: pods=2
```

## Step 5: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-050/module-02/labs/lab-02
```
