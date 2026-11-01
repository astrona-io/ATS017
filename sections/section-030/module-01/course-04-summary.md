# Summary

An autoscaler needs two numbers for each pod: how much CPU the pod uses and how much it requested. This module followed both numbers from the kubelet to the replica count.

## What you learned

The kubelet measures the usage of each container. metrics-server collects it every 15 seconds and serves the latest value through the Metrics API (`metrics.k8s.io`), which the API server forwards to it. `kubectl top` and the HPA controller are both clients of that API. The API holds usage only, with no history, no requests and no limits. When `kubectl get apiservice v1beta1.metrics.k8s.io` does not show `AVAILABLE True`, `kubectl top` fails and every HPA shows `<unknown>`.

An `autoscaling/v2` HorizontalPodAutoscaler names a workload in `scaleTargetRef`, a range with `minReplicas` and `maxReplicas`, and a list of `metrics`. For a CPU `Utilization` target, the HPA divides each pod's usage by its CPU request, averages the result, and applies `desiredReplicas = ceil(currentReplicas × currentUtilisation / targetUtilisation)`. It then limits the result to the minimum and the maximum and to the `behavior` rules. A ratio within 10 percent of 1.0 changes nothing. The conditions `ScalingActive` and `ScalingLimited` and the events in `kubectl describe hpa` show why the HPA did or did not scale.

A container without a CPU request gives the message `missing request for cpu in container ...` and a target of `<unknown>`. The fix is a CPU request in the Deployment. A Metrics API that does not answer gives the message `unable to fetch metrics from resource metrics API`. The fix is in metrics-server.

By default the HPA scales up fast and scales down after a stabilization window of 300 seconds. The `behavior` section changes this for each direction with `stabilizationWindowSeconds`, a list of `policies` of type `Pods` or `Percent` with a `periodSeconds`, and `selectPolicy`. The key facts to remember are these:

- The HPA scales on usage divided by requests, so a pod without a CPU request cannot be scaled on CPU.
- The result of the formula is always limited by `minReplicas`, `maxReplicas` and `behavior`.
- `ScalingLimited True` with `TooManyReplicas` means the maximum holds the count back.
- The window sets when scale-down may start, and the policy sets how fast it goes.

<!-- astrona:playground:destroy -->
