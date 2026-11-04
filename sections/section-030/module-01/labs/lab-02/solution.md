---
estimated_duration: 20m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-030/module-01/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Read the current HPA

Print the spec of the HPA:

```bash
kubectl -n starfleet get hpa scout -o yaml
```

The `spec` has `scaleTargetRef`, `minReplicas`, `maxReplicas` and `metrics`, and no `behavior`. Without `behavior`, the HPA controller uses its defaults: a scale-down stabilization window of 300 seconds and no limit on how many pods it removes in one step after the window.

## Step 2: Write the new HPA

Save this as `hpa-scout.yaml`. It keeps every existing field and adds `behavior.scaleDown`. The window of `120` seconds makes the HPA use the highest recommended replica count of the last two minutes. The policy removes at most one pod every `30` seconds:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: scout
  namespace: starfleet
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scout
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 120
      policies:
        - type: Pods
          value: 1
          periodSeconds: 30
```

Apply it:

```bash
kubectl apply -f hpa-scout.yaml
```

## Step 3: Check the result

```bash
kubectl -n starfleet get hpa scout -o jsonpath='{.spec.behavior.scaleDown}{"\n"}'
```

The output shows the window and the policy.

## Step 4: Watch the behaviour

Start a load from `shuttle`. The command waits for 100 seconds:

```bash
kubectl -n starfleet exec deploy/shuttle -- sh -c 'for i in 1 2 3 4; do timeout 100 curl -s -o /dev/null -X POST "http://scout/token?[1-5000000]" & done; wait'
```

In another terminal, run `kubectl -n starfleet get hpa scout --watch`. The replica count rises to `5`. After the load ends, the CPU target falls to `1%`, but the replica count stays at `5` for the whole window and then drops by one pod at a time.

## Step 5: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-030/module-01/labs/lab-02
```
