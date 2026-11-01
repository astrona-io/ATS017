---
estimated_duration: 15m
---

# Solution

## Step 1: Find the reason for the restarts

List the pods and read the status of the container:

```bash
kubectl -n starfleet get pods -l app=scout
kubectl -n starfleet describe pod -l app=scout | grep -A6 "Last State"
```

`Last State` shows `Terminated` with `Reason: OOMKilled` and `Exit Code: 137`. The kernel killed the container because it used more memory than its limit of `64Mi`.

## Step 2: Set a memory request and limit

The program needs about 100 MB for the load plus its own memory, so a limit of `192Mi` leaves room. The request is lower than the limit, so the pod is `Burstable`.

```bash
kubectl -n starfleet set resources deployment/scout \
  --requests=cpu=50m,memory=128Mi \
  --limits=cpu=200m,memory=192Mi
kubectl -n starfleet rollout status deployment/scout
```

The Deployment controller creates a new pod with the new values.

## Step 3: Prove the fix

```bash
kubectl -n starfleet get pods -l app=scout
kubectl -n starfleet get pod -l app=scout -o jsonpath='{.items[0].status.qosClass}{"\n"}'
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://scout:9898/healthz
```

The pod shows `1/1 Running` with `0` restarts, the QoS class is `Burstable` and the request returns `200`.

## Step 4: Submit

```bash
astrona submit -c sections/section-010/module-01/labs/lab-01
```
