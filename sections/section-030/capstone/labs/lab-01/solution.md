---
estimated_duration: 40m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-030/capstone/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Measure the usage

Read the requests and the usage of `scout`:

```bash
kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
kubectl -n starfleet top pods
```

The Deployment requests `1` CPU and `1Gi`. The pod uses a few millicores and a few tens of mebibytes. The first `kubectl top` values appear about a minute after the cluster starts, so repeat the command if it says that metrics are not available.

## Step 2: Right-size the Deployment

A CPU request of `50m` and a memory request of `32Mi` cover the usage with headroom. A memory limit of `64Mi` keeps a ceiling and does not remove the limit:

```bash
kubectl -n starfleet set resources deployment/scout \
  --requests=cpu=50m,memory=32Mi --limits=memory=64Mi
kubectl -n starfleet rollout status deployment/scout
```

## Step 3: Create the HPA

Save this as `hpa-scout.yaml`:

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
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
```

Apply it:

```bash
kubectl apply -f hpa-scout.yaml
```

Then check that the target has a value, not `<unknown>`:

```bash
kubectl -n starfleet get hpa scout
```

The `TARGETS` column shows a percentage of `50%`. The HPA needs about a minute after it starts to read the first usage.

## Step 4: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-030/capstone/labs/lab-01
```

The check takes about seven minutes. The grader starts a load of `POST` requests from `shuttle`, waits for the HPA to add a replica, stops the load, and waits up to about five minutes for the replicas to return to `1`. A reference run printed:

```text
OK: scout requests 50m CPU and 32Mi memory, limit 64Mi
OK: the HPA scales Deployment/scout on CPU Utilization at 50 percent, 1 to 4 replicas
OK: scale-down stabilization window is 60 seconds
OK: the HPA reads 2% CPU utilisation
OK: scout scaled up to 2 replicas under load
OK: scout is back to 1 replica after the load stopped
```

## Why other fixes fail

Creating the HPA without right-sizing the request leaves utilisation near `0%`, and the HPA never adds a replica. A stabilization window of `300` seconds is outside the accepted range, because the replicas would not return within the time the grader waits.
