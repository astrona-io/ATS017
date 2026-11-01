# Making The Change Permanent And Right-Sizing Next To An HPA

An in-place resize is fast, but it lives only as long as the pod. This part shows what happens to a resized pod when it is replaced, how to put the final numbers in the Deployment template, and why a CPU change to requests and an HPA on CPU affect each other.

## The template is the source of truth

The `scout-overprovisioned` pod was resized in place to a CPU request of `10m` and a memory request of `32Mi`. Delete the pod, as a node drain or a crash would, and look at the replacement that the Deployment controller creates:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet delete pod -l app=scout-overprovisioned
kubectl -n starfleet rollout status deployment/scout-overprovisioned
kubectl -n starfleet get pods -l app=scout-overprovisioned -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,MEM_LIM:.spec.containers[0].resources.limits.memory'
```

You should see something like (the output of the first command is one line, and the `Waiting` lines of the second are left out):

```text
pod "scout-overprovisioned-58d47cf88d-pk57t" deleted from starfleet namespace
deployment "scout-overprovisioned" successfully rolled out
POD                                      CPU_REQ   MEM_REQ   MEM_LIM
scout-overprovisioned-58d47cf88d-7r95j   1         1Gi       1Gi
```

The new pod asks for `1` CPU and `1Gi` again. The Deployment controller builds every pod from `spec.template`, and the template never changed. The in-place resize was lost with the old pod.

Make the numbers permanent with `kubectl set resources`, which edits the template and starts a rollout. Before you run it, create an HPA that scales this Deployment on CPU, because the next section needs it. Save this as `hpa-scout-overprovisioned.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: scout-overprovisioned
  namespace: starfleet
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scout-overprovisioned
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

```sh
kubectl apply -f hpa-scout-overprovisioned.yaml
```

You should see:

```text
horizontalpodautoscaler.autoscaling/scout-overprovisioned created
```

Then check the result after about a minute:

```sh
kubectl -n starfleet get hpa scout-overprovisioned
```

You should see something like:

```text
NAME                    REFERENCE                          TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
scout-overprovisioned   Deployment/scout-overprovisioned   cpu: 0%/50%   1         4         1          50s
```

The HPA reads `0%` because it divides the usage (about `2m`) by the request (`1` CPU = `1000m`). With a request that is 500 times too large, the HPA would not scale until the pod used 500m. Now put the measured numbers in the template:

```sh
kubectl -n starfleet set resources deployment/scout-overprovisioned \
  --requests=cpu=10m,memory=32Mi --limits=memory=32Mi
kubectl -n starfleet rollout status deployment/scout-overprovisioned
kubectl -n starfleet get deployment scout-overprovisioned -o jsonpath='{.spec.template.spec.containers[0].resizePolicy}{"\n"}{.spec.template.spec.containers[0].resources}{"\n"}'
```

You should see something like (the `Waiting` lines vary):

```text
deployment.apps/scout-overprovisioned resource requirements updated
deployment "scout-overprovisioned" successfully rolled out
[{"resourceName":"cpu","restartPolicy":"NotRequired"},{"resourceName":"memory","restartPolicy":"RestartContainer"}]
{"limits":{"memory":"32Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}
```

The template holds the new resources, and it still holds the `resizePolicy` from the earlier patch. Every future pod starts with these numbers. Check the HPA again after a minute:

```sh
kubectl -n starfleet get hpa scout-overprovisioned
```

You should see something like:

```text
NAME                    REFERENCE                          TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
scout-overprovisioned   Deployment/scout-overprovisioned   cpu: 20%/50%   1         4         1          2m6s
```

The same usage of `2m` now gives `20%`, because the request is `10m`. The HPA reads a meaningful number, and a rise in load will move it toward the `50%` target.

## An HPA and a CPU request affect each other

The HPA computes utilisation as usage divided by the CPU request. A change to the CPU request therefore changes what the HPA sees, even when the load does not change. Lowering the request makes the same load look larger and adds replicas sooner. Raising it does the opposite.

Two rules follow. First, finish the right-sizing of the CPU request before you tune the HPA target, because the target only has meaning against a correct request. Second, do not resize the CPU of single pods in place while an HPA on CPU controls the Deployment. The pods would then have different requests, and the HPA averages the utilisation of pods that divide by different numbers. Change the template, so every replica has the same request.

Memory is different. An HPA on CPU does not read the memory request, so a memory resize does not change its decisions. Take care only with the restart that `resizePolicy: RestartContainer` causes.

You now know the whole path: measure the usage, choose a request with headroom, apply it to a running pod when a restart is not acceptable, and write the same numbers into the Deployment template so they survive. The numbers also decide how an HPA reads the workload, so the right-sizing comes first and the autoscaling target second.

## Common pitfalls

> [!WARNING]
> - **Stopping after the in-place resize.** The Deployment template still holds the old numbers. The next pod, from a drain, a crash or a rollout, starts with them again.
> - **Tuning the HPA target before the request.** Utilisation is usage divided by the request. A wrong request makes every target wrong.
> - **Resizing single pods under an HPA.** Replicas with different CPU requests give a misleading average utilisation. Edit the template instead.
> - **Forgetting the HPA after a request change.** A new CPU request changes the utilisation the HPA reads. Look at `kubectl get hpa` after every change.
