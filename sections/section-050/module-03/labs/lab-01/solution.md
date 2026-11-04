---
estimated_duration: 25m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-050/module-03/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Look at the cluster

```bash
kubectl -n kyverno get pods
kubectl get clusterpolicy
kubectl -n outpost get deploy probe -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

You should see the Kyverno controllers `Running`, no policy (`No resources found`), and `{}` for the resources of `probe`.

## Step 2: Write the policy

A `validate` rule with `failureAction: Enforce` denies a request that does not match the `pattern`. The value `"?*"` means any non-empty value. Save this as `clusterpolicy-require-resources.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-requests-limits
spec:
  background: true
  rules:
    - name: require-requests-and-memory-limit
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["outpost"]
      validate:
        failureAction: Enforce
        message: "Every container needs CPU and memory requests and a memory limit."
        pattern:
          spec:
            containers:
              - resources:
                  requests:
                    cpu: "?*"
                    memory: "?*"
                  limits:
                    memory: "?*"
```

Apply it and wait for `READY True`:

```bash
kubectl apply -f clusterpolicy-require-resources.yaml
kubectl get clusterpolicy
```

## Step 3: Prove it

Create a pod without resources:

```bash
kubectl -n outpost run bare --image=mccutchen/go-httpbin:2.25.0
```

You should see an error like (wait a few seconds and run it again if the pod is created):

```text
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request: 

resource Pod/outpost/bare was blocked due to the following policies 

require-requests-limits:
  require-requests-and-memory-limit: 'validation error: Every container needs CPU and memory requests and a memory limit. rule require-requests-and-memory-limit failed at path /spec/containers/0/resources/limits/'
```

The same command in `starfleet` still works, because the policy matches only `outpost`:

```bash
kubectl -n starfleet run bare --image=mccutchen/go-httpbin:2.25.0
kubectl -n starfleet delete pod bare
```

## Step 4: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-050/module-03/labs/lab-01
```
