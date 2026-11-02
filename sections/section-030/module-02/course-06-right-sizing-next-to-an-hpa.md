# Right-Sizing Next To An HPA

A HorizontalPodAutoscaler (HPA) changes the replica count of a workload to keep a metric near a target. When the metric is CPU utilisation, the HPA depends on the CPU request of the pods. This part shows what happens when that request changes while the HPA is running.

The commands below need the `scout-overprovisioned` Deployment with one pod, a CPU request of `10m` and an HPA named `scout-overprovisioned` that targets `50%` CPU utilisation, with a minimum of 1 and a maximum of 4 replicas.

<!-- astrona:playground:renew -->

## An HPA and a CPU request affect each other

The HPA computes utilisation as usage divided by the CPU request. A change to the CPU request therefore changes what the HPA sees, even when the load does not change. Lowering the request makes the same load look larger and adds replicas sooner. Raising it does the opposite.

The cluster shows this. The Deployment now has one pod with a CPU request of `10m`, and the HPA reads about `20%`. Resize that pod in place to a CPU request of `2m`, which is about what the pod uses. The `resize` subresource accepts the change, because it touches only the pod and not the Deployment:

```sh
POD=$(kubectl -n starfleet get pod -l app=scout-overprovisioned -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet patch pod $POD --subresource resize --patch '{"spec":{"containers":[{"name":"scout","resources":{"requests":{"cpu":"2m"}}}]}}'
sleep 20
kubectl -n starfleet get hpa scout-overprovisioned
```

You should see something like (the exact percentages vary with the usage at that second):

```text
pod/scout-overprovisioned-6f74df5477-qz7g5 patched
NAME                    REFERENCE                          TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
scout-overprovisioned   Deployment/scout-overprovisioned   cpu: 100%/50%  1         4         1          7m39s
```

The load did not change. The pod still uses about `2m`, but the request fell from `10m` to `2m`, so the utilisation that the HPA calculates rose from about `20%` to `100%`. The HPA is now above its `50%` target and adds a replica. Wait about 20 seconds and look at the HPA again, then at the requests of the pods:

```sh
kubectl -n starfleet get hpa scout-overprovisioned
kubectl -n starfleet get pods -l app=scout-overprovisioned -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu'
```

You should see something like:

```text
NAME                    REFERENCE                          TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
scout-overprovisioned   Deployment/scout-overprovisioned   cpu: 25%/50%   1         4         2          8m19s
POD                                      CPU_REQ
scout-overprovisioned-6f74df5477-4gt9g   10m
scout-overprovisioned-6f74df5477-qz7g5   2m
```

The HPA now has two replicas. The new pod comes from the Deployment template, so it asks for `10m`, and the resized pod asks for `2m`. The HPA divides the total usage by the total of these two different requests, so the `25%` it reports is an average over pods that were sized differently. In a longer run on the same cluster the percentage kept moving between about `16%` and `100%`, and the HPA scaled between one and two replicas, because the number depends on which pods exist at that moment. In an earlier run, started while the template still asked for `1` CPU, the same in-place resize to `1m` made the HPA read `300%` and scale to the maximum of `4` replicas, each new pod with a request of `1` CPU.

Two rules follow. First, finish the right-sizing of the CPU request before you tune the HPA target, because the target only has meaning against a correct request. Second, do not resize the CPU of single pods in place while an HPA on CPU controls the Deployment. The pods would then have different requests, and the HPA averages the utilisation of pods that divide by different numbers. Change the template, so every replica has the same request.

Memory is different. An HPA on CPU does not read the memory request, so a memory resize does not change its decisions. Take care only with the restart that `resizePolicy: RestartContainer` causes.

You now know the whole path: measure the usage, choose a request with headroom, apply it to a running pod when a restart is not acceptable, and write the same numbers into the Deployment template so they survive. The numbers also decide how an HPA reads the workload, so the right-sizing comes first and the autoscaling target second.

## Common pitfalls

> [!WARNING]
> - **Resizing single pods under an HPA.** Replicas with different CPU requests give a misleading average utilisation. Edit the template instead.
> - **Forgetting the HPA after a request change.** A new CPU request changes the utilisation the HPA reads. Look at `kubectl get hpa` after every change.
