# Bound Recommendations For A StatefulSet

The `probe` StatefulSet needs a predictable resource budget even when its measured usage changes. A **StatefulSet** maintains Pods with stable names and ordered replacement. The **Vertical Pod Autoscaler (VPA)** can recommend requests for those Pods through the StatefulSet's selector. It does not choose the replica count.

Use `Initial` to let VPA assign requests only when a Pod is created. A **request** is the resource amount reserved by the scheduler. A **container policy** sets which container and resources VPA controls, plus the range its recommendations may use.

<!-- astrona:playground:renew -->
Save this as `vpa-probe.yaml`:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: probe
  namespace: starfleet
spec:
  targetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: probe
  updatePolicy:
    updateMode: Initial
  resourcePolicy:
    containerPolicies:
    - containerName: probe
      controlledResources:
      - cpu
      - memory
      controlledValues: RequestsOnly
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: 300m
        memory: 256Mi
```

Apply it:

```sh
kubectl apply -f vpa-probe.yaml
```

Then check the result:

```sh
kubectl -n starfleet wait --for=condition=RecommendationProvided vpa/probe --timeout=600s
kubectl -n starfleet get vpa probe -o yaml
kubectl -n starfleet get pod probe-0 -o yaml
```

`containerName: probe` selects the application container. `controlledResources` selects CPU and memory. `minAllowed` prevents a recommended request below `50m` CPU or `64Mi` memory. `maxAllowed` caps it at `300m` CPU and `256Mi` memory. A container name of `"*"` would provide a default for containers without a named policy; naming the container keeps the scope explicit.

`controlledValues: RequestsOnly` leaves limits alone. A **limit** caps the resources a container can use. The bounds in this policy constrain recommended requests, not usage. The Pod's limits remain `1` CPU and `1Gi` memory, which can contain every request in the policy range. The default `RequestsAndLimits` can also adjust limits, so set the field deliberately.

In the VPA status, compare `target` with `uncappedTarget`. If the estimate falls outside the policy, the bounded target can differ from the uncapped estimate. The two may also be equal. Do not expect one fixed value: your samples determine the estimate.

The existing `probe-0` Pod still uses its original resources. `Initial` does not update a running Pod when a new recommendation arrives. Read its unique identifier (UID) and requests before replacing it:

```sh
kubectl -n starfleet get pod probe-0 -o jsonpath='{.metadata.uid}{"\n"}{.spec.containers[0].resources}{"\n"}'
```

Record the UID in your notes. Then replace the Pod after the recommendation is available:

```sh
kubectl -n starfleet delete pod probe-0
kubectl -n starfleet rollout status statefulset/probe --timeout=180s
kubectl -n starfleet get pod probe-0 -o yaml
```

The StatefulSet creates another Pod named `probe-0`. Its UID must differ. Look for bounded CPU and memory requests, readiness, and the `vpaUpdates` annotation that records the admission changes. The admission controller applies the recommendation during creation; the StatefulSet supplies the stable name. A replacement can briefly interrupt this one-replica example.

Finally, compare the running container with the template:

```sh
kubectl -n starfleet get pod probe-0 -o jsonpath='{.status.containerStatuses[0].resources}{"\n"}'
kubectl -n starfleet get statefulset probe -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

The running request should match the Pod's request. The template still holds `500m` CPU and `512Mi` memory. VPA changes the new Pod, not that template. If you remove VPA, later Pods use the template again.

You can now keep creation-time recommendations within a resource budget and prove that a replacement received them. A Deployment uses the same policy fields, but replacement names and the choice of other autoscalers need separate attention.

## Common pitfalls

> [!WARNING]
> `Initial` leaves existing Pods unchanged. A StatefulSet Pod can keep its name after replacement, so compare UIDs. `maxAllowed` caps the recommended request; it does not replace the container limit.
