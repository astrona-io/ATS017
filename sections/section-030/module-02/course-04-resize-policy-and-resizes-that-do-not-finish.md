# resizePolicy And Resizes That Do Not Finish

A resize is a request, and a request can wait, fail or need a restart. The kubelet cannot always change a running container as asked. This part sets `resizePolicy` to control which resource may change without a restart, and it reads the conditions and events that tell you when a resize is stuck.

## Choose which resource needs a restart

Some programs read their memory size once at start and cannot use a new value while they run. Others, such as a program that sizes its thread pool from the CPU count, are fine with a CPU change at any time. The container field **`resizePolicy`** lists, for each resource, what the kubelet does on a resize. The value `NotRequired` means the kubelet changes the limits of the running container. The value `RestartContainer` means the kubelet restarts the container in the same pod. If you set no policy, the default for every resource is `NotRequired`.

`resizePolicy` belongs to the container in the pod template, so you add it to the Deployment. Save this patch as `patch-resizepolicy.yaml`:

<!-- astrona:playground:renew -->

```yaml
spec:
  template:
    spec:
      containers:
        - name: scout
          resizePolicy:
            - resourceName: cpu
              restartPolicy: NotRequired
            - resourceName: memory
              restartPolicy: RestartContainer
```

Apply it to the Deployment `scout-overprovisioned` and wait for the new pod:

```sh
kubectl -n starfleet patch deployment scout-overprovisioned --patch-file patch-resizepolicy.yaml
kubectl -n starfleet rollout status deployment/scout-overprovisioned
```

You should see something like:

```text
deployment.apps/scout-overprovisioned patched
Waiting for deployment "scout-overprovisioned" rollout to finish: 1 old replicas are pending termination...
deployment "scout-overprovisioned" successfully rolled out
```

The template change created a new pod, as any template change does. The new pod has the policy in its `spec`, and it has the template's requests again (`1` CPU and `1Gi`). Store its name and show the UID, so you can follow it:

```sh
POD=$(kubectl -n starfleet get pod -l app=scout-overprovisioned -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet get pod $POD -o custom-columns='CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,RESTARTS:.status.containerStatuses[0].restartCount,UID:.metadata.uid'
```

You should see something like:

```text
CPU_REQ   MEM_REQ   RESTARTS   UID
1         1Gi       0          3f02fa3f-f19f-4519-bbea-d749182601aa
```

Resize the CPU first. The policy says `NotRequired`, so the kubelet changes it in place:

```sh
kubectl -n starfleet patch pod $POD --subresource resize --patch '{"spec":{"containers":[{"name":"scout","resources":{"requests":{"cpu":"10m"}}}]}}'
kubectl -n starfleet get pod $POD -o custom-columns='CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,RESTARTS:.status.containerStatuses[0].restartCount,UID:.metadata.uid'
```

You should see something like:

```text
pod/scout-overprovisioned-58d47cf88d-pk57t patched
CPU_REQ   MEM_REQ   RESTARTS   UID
10m       1Gi       0          3f02fa3f-f19f-4519-bbea-d749182601aa
```

Now resize the memory. Its policy is `RestartContainer`. The memory request and limit go together, because the limit may not stay below the request:

```sh
kubectl -n starfleet patch pod $POD --subresource resize --patch '{"spec":{"containers":[{"name":"scout","resources":{"requests":{"memory":"32Mi"},"limits":{"memory":"32Mi"}}}]}}'
kubectl -n starfleet get pod $POD -o custom-columns='CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,RESTARTS:.status.containerStatuses[0].restartCount,UID:.metadata.uid'
kubectl -n starfleet get events --field-selector involvedObject.name=$POD,reason=Killing
```

You should see something like:

```text
pod/scout-overprovisioned-58d47cf88d-pk57t patched
CPU_REQ   MEM_REQ   RESTARTS   UID
10m       32Mi      1          3f02fa3f-f19f-4519-bbea-d749182601aa
LAST SEEN   TYPE     REASON    OBJECT                                       MESSAGE
7s          Normal   Killing   pod/scout-overprovisioned-58d47cf88d-pk57t   Container scout resize requires restart
```

The UID did not change, so the pod is the same, but `RESTARTS` is now `1`. The kubelet restarted the container because the memory policy demanded it. The CPU change cost no restart and the memory change cost one. That is the whole effect of `resizePolicy`.

## Read a resize that does not finish

A resize can also fail because the node cannot give the amount. Ask for `100` CPU on a node that has `6`:

```sh
kubectl -n starfleet patch pod $POD --subresource resize --patch '{"spec":{"containers":[{"name":"scout","resources":{"requests":{"cpu":"100"}}}]}}'
kubectl -n starfleet get pod $POD -o jsonpath='{range .status.conditions[?(@.type=="PodResizePending")]}{.type} {.status} {.reason} {.message}{"\n"}{end}'
```

You should see something like:

```text
pod/scout-overprovisioned-58d47cf88d-pk57t patched
PodResizePending True Infeasible Node didn't have enough capacity: cpu, requested: 100000, capacity: 6000
```

The API server accepted the request, because a node of any size could exist. The kubelet checked the node, found no room, and set the condition `PodResizePending` with the reason `Infeasible`. It also wrote a `ResizeInfeasible` warning event. The container keeps running with its old values. Fix the request with a second resize and the condition goes away:

```sh
kubectl -n starfleet patch pod $POD --subresource resize --patch '{"spec":{"containers":[{"name":"scout","resources":{"requests":{"cpu":"10m"}}}]}}'
kubectl -n starfleet get pod $POD -o jsonpath='{.status.conditions[*].type}{"\n"}'
```

You should see something like:

```text
pod/scout-overprovisioned-58d47cf88d-pk57t patched
PodReadyToStartContainers Initialized Ready ContainersReady PodScheduled
```

The list has no `PodResizePending` any more. A second kind of stuck resize is a memory limit below the current usage. The kernel cannot lower a cgroup memory limit under the memory the container already uses. Try it on `scout-underprovisioned`, which uses about `166Mi`:

```sh
POD_UNDER=$(kubectl -n starfleet get pod -l app=scout-underprovisioned -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet patch pod $POD_UNDER --subresource resize --patch '{"spec":{"containers":[{"name":"scout","resources":{"requests":{"memory":"64Mi"},"limits":{"memory":"64Mi"}}}]}}'
kubectl -n starfleet get pod $POD_UNDER -o jsonpath='{range .status.conditions[?(@.type=="PodResizeInProgress")]}{.type} {.status} {.reason}{"\n"}{end}'
```

You should see something like:

```text
pod/scout-underprovisioned-7f9bd47dfc-c7fmp patched
PodResizeInProgress True
```

The condition `PodResizeInProgress` stays `True`, and the container keeps its old limit of `224Mi`. The event list gives the reason:

```sh
kubectl -n starfleet get events --field-selector involvedObject.name=$POD_UNDER,reason=ResizeError
```

The message is long. It starts like this (shortened):

```text
LAST SEEN   TYPE      REASON        OBJECT                                        MESSAGE
5s          Warning   ResizeError   pod/scout-underprovisioned-7f9bd47dfc-c7fmp   Pod resize error: {...,"error":"cannot decrease memory limits: [attempting to set pod memory limit (67108864) below current usage (172240896), ...
```

A new resize that sets the memory back to `224Mi` clears the condition. A resize that is rejected or stuck never harms the running container, so it is safe to try and read the condition.

You now know the three states of a resize: it finishes, it needs a restart because of `resizePolicy`, or it stays pending or in progress with a condition and an event that name the reason. The question that remains is how to make a good resize last, because every pod that the Deployment creates later starts from the template again.

## Common pitfalls

> [!WARNING]
> - **Setting `resizePolicy` on a pod.** The field belongs to the container in the pod template. Change it in the Deployment, and expect a new pod.
> - **Expecting no restart for memory.** With `RestartContainer`, the container restarts, and the restart count goes up by one. The pod keeps its UID.
> - **Lowering a memory limit below the usage.** The resize stays in progress and the event says `cannot decrease memory limits`. Check `kubectl top` first.
> - **Ignoring `PodResizePending`.** The container still runs with the old values. Read the condition `reason`: `Infeasible` means the node can never fit the request.
