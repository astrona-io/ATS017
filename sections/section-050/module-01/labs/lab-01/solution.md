---
estimated_duration: 20m
---

# Solution

## Step 1: Read the Deployment status

Look at the Deployment, then at the quota in the same namespace:

```bash
kubectl -n outpost get deploy probe
kubectl -n outpost describe resourcequota outpost-quota
```

The Deployment shows `2/4` ready. The quota shows `requests.cpu` at `400m` used of `500m`, so there is no room for a third pod that requests `200m`:

```text
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
probe   2/4     2            2           9s
Name:            outpost-quota
Namespace:       outpost
Resource         Used   Hard
--------         ----   ----
limits.memory    256Mi  1Gi
pods             2      10
requests.cpu     400m   500m
requests.memory  128Mi  512Mi
```

## Step 2: Read the rejection

The Deployment controller records why it cannot create the pods in the `ReplicaFailure` condition:

```bash
kubectl -n outpost get deploy probe -o jsonpath='{.status.conditions[?(@.type=="ReplicaFailure")].message}{"\n"}'
```

The message names the quota line that is full:

```text
pods "probe-6bf487b57f-88xrt" is forbidden: exceeded quota: outpost-quota, requested: requests.cpu=200m, used: requests.cpu=400m, limited: requests.cpu=500m
```

## Step 3: Choose the fix

The quota is the share of the namespace, so it stays as it is. Four replicas must fit in `500m`, so each pod can request at most `125m`. The grader accepts a request between `50m` and `120m`. Use `100m`, which leaves room for the pod rollout.

## Step 4: Lower the CPU request

Change only the CPU request. The command keeps the memory values that exist:

```bash
kubectl -n outpost set resources deployment/probe --requests=cpu=100m
kubectl -n outpost rollout status deployment/probe --timeout=180s
```

The Deployment uses the `Recreate` strategy, so it deletes the two old pods first and then creates four new pods with the new request.

## Step 5: Prove it

```bash
kubectl -n outpost get deploy probe
kubectl -n outpost describe resourcequota outpost-quota
```

You should see something like:

```text
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
probe   4/4     4            4           5s
Name:            outpost-quota
Namespace:       outpost
Resource         Used   Hard
--------         ----   ----
limits.memory    512Mi  1Gi
pods             4      10
requests.cpu     400m   500m
requests.memory  256Mi  512Mi
```

## Step 6: Submit

```bash
astrona submit -c sections/section-050/module-01/labs/lab-01
```
