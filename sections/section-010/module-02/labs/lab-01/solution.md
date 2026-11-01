---
estimated_duration: 15m
---

# Solution

## Step 1: Read why the pods are Pending

```bash
kubectl -n outpost get pods
kubectl -n outpost describe pod -l app=probe | grep -A3 "Events"
```

The `FailedScheduling` message says that the node has the untolerated taint `{dedicated: outpost}` and that the other node did not match the node selector.

## Step 2: Add a toleration

A toleration allows the pod onto the tainted node. The `nodeSelector` already pulls it to `zone-b`. Patch the Deployment:

```bash
kubectl -n outpost patch deployment probe --type=json -p='[
  {"op":"add","path":"/spec/template/spec/tolerations","value":[
    {"key":"dedicated","operator":"Equal","value":"outpost","effect":"NoSchedule"}]}
]'
kubectl -n outpost rollout status deployment/probe
```

## Step 3: Prove the placement

```bash
kubectl -n outpost get pods -o wide
kubectl get node -l topology.kubernetes.io/zone=zone-b
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://probe.outpost:8080/status/200
```

Both `probe` pods show the `zone-b` node in the `NODE` column and the request returns `200`.

## Step 4: Submit

```bash
astrona submit -c sections/section-010/module-02/labs/lab-01
```
