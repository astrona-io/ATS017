# Read Recommendations Without Changing Pods

The `scout` Deployment reserves more CPU and memory than its idle Pods may need. You want to measure that gap before allowing an automatic change. The **Vertical Pod Autoscaler (VPA)** is a controller system that computes resource recommendations from container usage. A `VerticalPodAutoscaler` object selects the workload and sets how those recommendations may be applied.

Start with a recommendation-only object. A **Deployment** maintains Pods from a shared template. The `targetRef` below points at that controller, rather than at one temporary Pod name. The **request** is the CPU or memory reserved for a container; `RequestsOnly` keeps the container's limits unchanged if you later enable updates.

<!-- astrona:playground:renew -->
Save this as `vpa-scout.yaml`:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: scout
  namespace: starfleet
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scout
  updatePolicy:
    updateMode: "Off"
  resourcePolicy:
    containerPolicies:
      - containerName: scout
        controlledResources: [cpu, memory]
        controlledValues: RequestsOnly
```

Apply it:

```sh
kubectl apply -f vpa-scout.yaml
```

Then check the result:

```sh
kubectl -n starfleet top pods --containers
kubectl -n starfleet get deployment scout -o yaml
kubectl -n starfleet describe vpa scout
```

Compare the measured CPU and memory usage with the requests in the Deployment template. The recommender, the VPA component that calculates resource sizes, needs samples before it can publish a result. An empty recommendation immediately after creation does not mean that `Off` has disabled measurement.

Wait for the recommendation condition, then read the object:

```sh
kubectl -n starfleet wait --for=condition=RecommendationProvided vpa/scout --timeout=600s
kubectl -n starfleet get vpa scout -o yaml
```

Look under `status.recommendation.containerRecommendations` for the entry whose `containerName` is `scout`. Each container has a `target`, the request VPA currently recommends. `lowerBound` and `upperBound` describe the recommendation range; they are not container limits. `uncappedTarget` shows the estimate before the container policy's minimum and maximum are applied. These fields hold quantities, so a memory number without a suffix is bytes, not mebibytes.

With `updateMode: "Off"`, VPA calculates recommendations but does not apply them to Pods. The admission controller, the component that can change a Pod during creation, leaves these requests alone. The updater, the component that can change existing Pods in other modes, does not resize or evict them in this mode.

Read the Pod resources and the Deployment template separately:

```sh
kubectl -n starfleet get pods -l app=scout -o yaml
kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

The Pod requests should still match the starting template. A recommendation is advice until the update policy allows it to affect a Pod. Keep collecting measurements across busy and quiet periods before choosing production requests; a low idle sample does not describe a peak.

If the wait times out, inspect `status.conditions` with `kubectl describe vpa scout`. Check that `targetRef` matches the controller, that its Pods are Ready, and that `kubectl top` returns usage. Those checks separate a missing target from missing measurements.

You can now read a recommendation without changing the application. The next decision is how much freedom the recommendation should have, because a measured estimate still needs a safe operating range.

## Common pitfalls

> [!WARNING]
> `Off` still computes recommendations. An empty status needs diagnosis, not a different update mode. Point `targetRef` at the Deployment, not a Pod, and read memory quantities with their units.
