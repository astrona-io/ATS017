---
estimated_duration: 30m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-050/module-03/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Look at the cluster

```bash
kubectl -n kyverno get pods
kubectl get clusterpolicy
```

You should see the Kyverno controllers `Running` and no policy.

## Step 2: Write the policy

A `generate` rule creates an object when a matching resource appears. The `match` block selects namespaces by label. The `generate` block names the new object, and `"{{request.object.metadata.name}}"` is the name of the namespace that triggered the rule. `synchronize: true` makes Kyverno create the object again if it is deleted. Save this as `clusterpolicy-tenant-defaults.yaml`:

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

Apply it and wait for `READY True`:

```bash
kubectl apply -f clusterpolicy-tenant-defaults.yaml
kubectl get clusterpolicy
```

## Step 3: Prove it

Save a tenant namespace as `namespace-tenant-a.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a
  labels:
    tenant: "true"
```

Apply it and look at what Kyverno created (wait a few seconds first):

```bash
kubectl apply -f namespace-tenant-a.yaml
kubectl -n tenant-a get resourcequota,limitrange
```

You should see something like:

```text
NAME                         REQUEST                                                      LIMIT                    AGE
resourcequota/tenant-quota   pods: 0/10, requests.cpu: 0/200m, requests.memory: 0/256Mi   limits.memory: 0/512Mi   8s

NAME                         CREATED AT
limitrange/tenant-defaults   2026-11-02T03:27:00Z
```

Delete the quota and check that Kyverno creates it again:

```bash
kubectl -n tenant-a delete resourcequota tenant-quota
kubectl -n tenant-a get resourcequota
```

## Step 4: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-050/module-03/labs/lab-02
```
