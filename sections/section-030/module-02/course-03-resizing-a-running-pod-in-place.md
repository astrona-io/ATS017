# Resizing A Running Pod In Place

Changing the requests of a Deployment replaces its pods. For a workload that holds data in memory, keeps connections open, or takes minutes to warm up, a new pod is a cost. This part changes the resources of a running pod without replacing it, and it shows which parts of the pod object record the change.

## The rule before Kubernetes 1.35

A pod's `spec.containers[*].resources` was immutable for years. The API server refused every edit, and the only way to change a request was to delete the pod and let the Deployment create a new one. The feature **in-place pod resize** removes that limit. It is enabled by default in Kubernetes 1.35, the exam version, and a change goes through a special **subresource** of the pod called `resize`. A subresource is a separate API path under an object, with its own rules, in the same way as `status` or `scale`.

Take the running pod of `scout-overprovisioned`. First store its name and show what the API holds about its resources:

<!-- astrona:playground:renew -->

```sh
POD=$(kubectl -n starfleet get pod -l app=scout-overprovisioned -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet get pod $POD -o jsonpath='uid={.metadata.uid} restarts={.status.containerStatuses[0].restartCount}{"\n"}spec={.spec.containers[0].resources}{"\n"}status={.status.containerStatuses[0].resources}{"\n"}allocated={.status.containerStatuses[0].allocatedResources}{"\n"}'
```

You should see something like:

```text
uid=092b4b9d-3af1-4436-81f5-a35be4e87105 restarts=0
spec={"limits":{"memory":"1Gi"},"requests":{"cpu":"1","memory":"1Gi"}}
status={"limits":{"memory":"1Gi"},"requests":{"cpu":"1","memory":"1Gi"}}
allocated={"cpu":"1","memory":"1Gi"}
```

The pod now records its resources in three places. `spec.containers[0].resources` is what you ask for. `status.containerStatuses[0].resources` is what the container runs with now. `allocatedResources` is what the kubelet has reserved on the node for the container. A resize changes the first one, and the kubelet then makes the other two follow. When all three are equal, the resize is finished.

## Try a plain patch, then use the subresource

Try to lower the CPU request with an ordinary patch:

```sh
kubectl -n starfleet patch pod $POD --patch '{"spec":{"containers":[{"name":"scout","resources":{"requests":{"cpu":"10m"}}}]}}'
```

The API server rejects it:

```text
The Pod "scout-overprovisioned-786cfdfb8d-tsdqw" is invalid: spec: Forbidden: pod updates may not change fields other than `spec.containers[*].image`,`spec.initContainers[*].image`,`spec.activeDeadlineSeconds`,`spec.tolerations` (only additions to existing tolerations),`spec.terminationGracePeriodSeconds` (allow it to be set to 1 if it was previously negative)
```

Send the same kind of change to the `resize` subresource with `--subresource resize`. This request lowers the CPU request to `10m` and the memory request and limit to `32Mi`, the values from the measurements:

```sh
kubectl -n starfleet patch pod $POD --subresource resize --patch '{"spec":{"containers":[{"name":"scout","resources":{"requests":{"cpu":"10m","memory":"32Mi"},"limits":{"memory":"32Mi"}}}]}}'
kubectl -n starfleet get pod $POD -o jsonpath='uid={.metadata.uid} restarts={.status.containerStatuses[0].restartCount}{"\n"}spec={.spec.containers[0].resources}{"\n"}status={.status.containerStatuses[0].resources}{"\n"}allocated={.status.containerStatuses[0].allocatedResources}{"\n"}'
```

You should see something like:

```text
pod/scout-overprovisioned-786cfdfb8d-tsdqw patched
uid=092b4b9d-3af1-4436-81f5-a35be4e87105 restarts=0
spec={"limits":{"memory":"32Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}
status={"limits":{"memory":"32Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}
allocated={"cpu":"10m","memory":"32Mi"}
```

The UID is the same and `restarts` is still `0`. The pod and its container are the original ones, and all three records show the new values. The kubelet is the component that did the work: it saw the changed `spec`, asked the container runtime to update the cgroup limits of the running container, and then wrote the new values to the pod status.

The pod also records the change as events. The command below shows only the two resize events:

```sh
kubectl -n starfleet get events --field-selector involvedObject.name=$POD | grep -E 'LAST SEEN|Resize'
```

You should see something like (shortened to the resize lines):

```text
LAST SEEN   TYPE     REASON            OBJECT                                       MESSAGE
4s          Normal   ResizeStarted     pod/scout-overprovisioned-786cfdfb8d-tsdqw   Pod resize started: {"containers":[{"name":"scout","resources":{"limits":{"memory":"32Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}}],"generation":2}
3s          Normal   ResizeCompleted   pod/scout-overprovisioned-786cfdfb8d-tsdqw   Pod resize completed: {"containers":[{"name":"scout","resources":{"limits":{"memory":"32Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}}],"generation":2}
```

Last, check what the Deployment holds. The change touched one pod, not the template that creates pods:

```sh
kubectl -n starfleet get deployment scout-overprovisioned -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

You should see:

```text
{"limits":{"memory":"1Gi"},"requests":{"cpu":"1","memory":"1Gi"}}
```

The template still asks for `1` CPU and `1Gi`. If this pod is deleted or the node drains, the Deployment creates a replacement with those old values. An in-place resize changes one live pod. To make it permanent you must also edit the template.

You can now change the requests and limits of a running container without a restart, and you know where to read the result: the `spec`, the status and `allocatedResources`. Two questions remain: what happens when a resource needs a restart, and what happens when the node cannot give the new amount.

## Common pitfalls

> [!WARNING]
> - **Using `kubectl patch` without `--subresource resize`.** The API server answers `Forbidden`, because a pod's resources are not editable through the normal path.
> - **Reading only `spec` to prove the change.** The `spec` shows what you asked for. The proof is `status.containerStatuses[*].resources`, which shows what the container runs with.
> - **Expecting the Deployment to change.** An in-place resize edits one pod. The Deployment template, and every future pod, keep the old values.
> - **Changing the QoS class.** A resize may not move a pod from one QoS class to another. The API server rejects it with the message `Pod QOS Class may not change as a result of resizing`.
