---
estimated_duration: 25m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-050/module-01/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Read the rejection

The Deployment shows `0/3`. Read why the ReplicaSet cannot create a pod, and look at the resources in the pod template:

```bash
kubectl -n outpost get deploy batch-worker
kubectl -n outpost get deploy batch-worker -o jsonpath='{.status.conditions[?(@.type=="ReplicaFailure")].message}{"\n"}'
kubectl -n outpost get deploy batch-worker -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

You should see something like:

```text
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
batch-worker   0/3     0            0           8s
pods "batch-worker-85d99cccf-dzshz" is forbidden: failed quota: outpost-quota: must specify limits.memory for: worker; requests.cpu for: worker; requests.memory for: worker
{}
```

The quota counts requests and the memory limit, so every container must declare them. The pod template declares nothing (`{}`), so the quota admission step rejects every pod.

## Step 2: Choose the fix

You may not edit the Deployment and you may not change the quota. A LimitRange of `type: Container` fills in the missing values at admission time, before the quota is checked. It also sets the maximum.

## Step 3: Create the LimitRange

Save this as `limitrange-outpost.yaml`:

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
        cpu: 50m
        memory: 64Mi
      default:
        memory: 128Mi
      max:
        memory: 256Mi
```

`defaultRequest` sets the request of a container that declares none. `default` sets the limit. `max` is the largest limit a container may ask for.

Apply it:

```bash
kubectl apply -f limitrange-outpost.yaml
```

## Step 4: Create the pods again

A LimitRange changes only pods created after it. The ReplicaSet tries again by itself after a pause, and a new rollout makes it try at once:

```bash
kubectl -n outpost rollout restart deployment/batch-worker
kubectl -n outpost rollout status deployment/batch-worker --timeout=180s
```

## Step 5: Prove it

```bash
kubectl -n outpost get pods -l app=batch-worker
kubectl -n outpost describe limitrange outpost-defaults
```

You should see something like (the old pods may still show `Terminating` for a moment):

```text
NAME                            READY   STATUS    RESTARTS   AGE
batch-worker-6bf745ddb4-2c84r   1/1     Running   0          2s
batch-worker-6bf745ddb4-pldmp   1/1     Running   0          3s
batch-worker-6bf745ddb4-tn424   1/1     Running   0          1s
Name:       outpost-defaults
Namespace:  outpost
Type        Resource  Min  Max    Default Request  Default Limit  Max Limit/Request Ratio
----        --------  ---  ---    ---------------  -------------  -----------------------
Container   memory    -    256Mi  64Mi             128Mi          -
Container   cpu       -    -      50m              -              -
```

## Step 6: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-050/module-01/labs/lab-02
```
