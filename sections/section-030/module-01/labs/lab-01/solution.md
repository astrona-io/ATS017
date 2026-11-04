---
estimated_duration: 20m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-030/module-01/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Read the HPA status

Look at the target column and then at the conditions and events:

```bash
kubectl -n starfleet get hpa scout
kubectl -n starfleet describe hpa scout
```

The target column shows `cpu: <unknown>/50%`. In `describe`, the condition `ScalingActive` is `False` with the reason `FailedGetResourceMetric`. The message and the event say that the HPA cannot read the CPU utilisation because the container `scout` has no CPU request.

## Step 2: Confirm the request is missing

Print the resources of the `scout` container:

```bash
kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

The output has a memory request and a memory limit, and no `cpu` request. The HPA computes utilisation as usage divided by the CPU request, so without a request it has nothing to divide by.

## Step 3: Add the CPU request

Add a request of `100m`. The command keeps the memory values that already exist:

```bash
kubectl -n starfleet set resources deployment/scout --requests=cpu=100m
kubectl -n starfleet rollout status deployment/scout
```

The Deployment controller creates a new pod with the request. The HPA reads the new pod after metrics-server has its first sample, about a minute later.

## Step 4: Prove the target resolves

```bash
kubectl -n starfleet get hpa scout
```

The target column now shows a number, such as `cpu: 1%/50%`. If it still shows `<unknown>`, wait 30 seconds and run the command again.

## Step 5: Prove the HPA scales up

Start a steady load from `shuttle`. The command waits for 100 seconds:

```bash
kubectl -n starfleet exec deploy/shuttle -- sh -c 'for i in 1 2 3 4; do timeout 100 curl -s -o /dev/null -X POST "http://scout/token?[1-5000000]" & done; wait'
```

In another terminal, watch the HPA:

```bash
kubectl -n starfleet get hpa scout --watch
```

The CPU target rises far above `50%` and the replica count grows within about a minute.

## Step 6: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-030/module-01/labs/lab-01
```
