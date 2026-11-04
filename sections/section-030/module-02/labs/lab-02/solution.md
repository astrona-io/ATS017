---
estimated_duration: 15m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-030/module-02/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Record the starting state

Store the pod name and print its UID, restart count and resources:

```bash
POD=$(kubectl -n starfleet get pod -l app=scout -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet get pod $POD -o jsonpath='uid={.metadata.uid} restarts={.status.containerStatuses[0].restartCount}{"\n"}status={.status.containerStatuses[0].resources}{"\n"}'
```

The restart count is `0`, and the resources are a CPU request of `100m`, a CPU limit of `200m`, and a memory request and limit of `64Mi` and `128Mi`. Write the UID down. The grader compares it at the end.

## Step 2: Resize the running pod

A plain `kubectl patch` of a pod is rejected. Send the new CPU request and limit to the `resize` subresource:

```bash
kubectl -n starfleet patch pod $POD --subresource resize --patch '{"spec":{"containers":[{"name":"scout","resources":{"requests":{"cpu":"500m"},"limits":{"cpu":"1"}}}]}}'
```

The request and the limit move together. A request of `500m` is above the old limit of `200m`, so the limit must rise in the same patch. The memory is not in the patch, so it does not change.

## Step 3: Prove it from the status

```bash
kubectl -n starfleet get pod $POD -o jsonpath='uid={.metadata.uid} restarts={.status.containerStatuses[0].restartCount}{"\n"}status={.status.containerStatuses[0].resources}{"\n"}conditions={.status.conditions[*].type}{"\n"}'
```

The UID is the one you wrote down, `restarts` is `0`, and the status shows `500m` and `1` for CPU and `64Mi` and `128Mi` for memory. The condition list has no `PodResizePending` and no `PodResizeInProgress`. If a resize condition is still there, wait a few seconds and run the command again. Press Ctrl-C to stop the watch, then submit the lab once:

```bash
astrona submit -c sections/section-030/module-02/labs/lab-02
```

A reference run printed:

```text
OK: the original scout pod is still running (UID unchanged)
OK: the container was not restarted
OK: the container runs with a CPU request of 500m and a CPU limit of 1
OK: memory is unchanged and the container is Ready
```

## Why other fixes fail

Editing the Deployment or deleting the pod creates a new pod with a new UID, so the grader rejects it. Changing only the request and leaving the CPU limit at `200m` is refused by the API server, because the request may not be above the limit.
