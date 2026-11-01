# Unknown Targets And Scaling Behavior

An HPA that works is only half of the job. On a real platform you must also know how to find out why an HPA does nothing, and how to control how fast it adds and removes pods. A target of `<unknown>` and a replica count that falls too fast are the two problems that show up most often. This part reads the evidence for the first and changes the `behavior` section of the HPA to fix the second.

## Write the HPA with a behavior section

The `behavior` field of an `autoscaling/v2` HPA sets the pace of scaling, one block for each direction: `scaleUp` and `scaleDown`. Each block has three fields. `stabilizationWindowSeconds` is a time window in which the HPA remembers its earlier recommendations. For scale-down, the HPA uses the highest recommendation of the window, so one quiet minute does not remove pods. `policies` is a list of limits. A policy of `type: Pods` allows that many pods to change in `periodSeconds`, and `type: Percent` allows that percentage of the current replicas. `selectPolicy` says which policy wins when there are several: `Max` (the default), `Min`, or `Disabled`, which turns scaling in that direction off.

This HPA keeps the metric from the earlier HPA, waits 60 seconds before it scales down, and then removes at most one pod every 15 seconds.

<!-- astrona:playground:renew -->

Save this as `hpa-scout.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: scout
  namespace: starfleet
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scout
  minReplicas: 1
  maxReplicas: 5
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
      policies:
        - type: Pods
          value: 1
          periodSeconds: 15
```

Apply it. If an HPA named `scout` already exists, `kubectl apply` updates it:

```sh
kubectl apply -f hpa-scout.yaml
```

Then read back the `behavior` field that the API server stored:

```sh
kubectl -n starfleet get hpa scout -o jsonpath='{.spec.behavior}{"\n"}'
```

You should see something like (one line in the terminal):

```text
{"scaleDown":{"policies":[{"periodSeconds":15,"type":"Pods","value":1}],"selectPolicy":"Max","stabilizationWindowSeconds":60},"scaleUp":{"policies":[{"periodSeconds":15,"type":"Pods","value":4},{"periodSeconds":15,"type":"Percent","value":100}],"selectPolicy":"Max","stabilizationWindowSeconds":0}}
```

You wrote only `scaleDown`. The API server filled in `scaleUp` with the defaults: no stabilization window, and two policies, up to 4 pods or up to 100 percent of the current replicas every 15 seconds, with `selectPolicy: Max` so the larger one wins. Without a `behavior` section, the HPA also scales down with a window of 300 seconds and a policy that allows 100 percent every 15 seconds, so all pods above the target can go at once.

## When the target is unknown

A target of `<unknown>` means the HPA could not compute a utilisation. The reason is always in the `ScalingActive` condition and in the events. Two causes cover almost every case. The first is a container without a CPU request, and its message is `missing request for cpu in container ...`. The second is a Metrics API that does not answer, and its message says `unable to fetch metrics from resource metrics API`.

Break the second one on purpose to see it. Scale metrics-server down to zero replicas:

```sh
kubectl -n kube-system scale deployment metrics-server --replicas=0
```

Wait about 75 seconds, then check the APIService, `kubectl top` and the HPA:

```sh
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top pods -n starfleet
kubectl -n starfleet get hpa scout
kubectl -n starfleet describe hpa scout | sed -n '/^Conditions/,$p'
```

You should see something like (the events are shortened to the two warnings):

```text
NAME                     SERVICE                      AVAILABLE                  AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   False (MissingEndpoints)   27m
error: Metrics API not available
NAME    REFERENCE          TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
scout   Deployment/scout   cpu: <unknown>/50%   1         5         1          10m
Conditions:
  Type            Status  Reason                   Message
  ----            ------  ------                   -------
  AbleToScale     True    SucceededGetScale        the HPA controller was able to get the target's current scale
  ScalingActive   False   FailedGetResourceMetric  the HPA was unable to compute the replica count: failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server is currently unable to handle the request (get pods.metrics.k8s.io)
  ScalingLimited  False   DesiredWithinRange       the desired count is within the acceptable range
Events:
  Type     Reason                        Age                From                       Message
  ----     ------                        ----               ----                       -------
  Warning  FailedGetResourceMetric       12s (x5 over 72s)  horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server is currently unable to handle the request (get pods.metrics.k8s.io)
  Warning  FailedComputeMetricsReplicas  12s (x5 over 72s)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server is currently unable to handle the request (get pods.metrics.k8s.io)
```

Three signs point at the same cause. The APIService shows `AVAILABLE False (MissingEndpoints)`, because no metrics-server pod serves it. `kubectl top` fails with `Metrics API not available`. The HPA message names the resource metrics API, not a container. The pods and their requests are fine, so editing the Deployment would not help here.

Bring metrics-server back and wait for the rollout:

```sh
kubectl -n kube-system scale deployment metrics-server --replicas=1
kubectl -n kube-system rollout status deployment metrics-server
```

After about 45 seconds the HPA shows `cpu: 1%/50%` again. The two causes lead to different fixes, so read the message first: a missing request is fixed in the workload, and a failing Metrics API is fixed in metrics-server.

## Watch a slow scale-down

With the `behavior` section in place, repeat the load test. Start the load from `shuttle`. The command stops after 100 seconds:

```sh
kubectl -n starfleet exec deploy/shuttle -- sh -c 'for i in 1 2 3 4; do timeout 100 curl -s -o /dev/null -X POST "http://scout/token?[1-5000000]" & done; wait'
```

In a second terminal, watch the HPA until the replicas are back at 1:

```sh
kubectl -n starfleet get hpa scout --watch
```

You should see something like (shortened, because the watch prints more lines):

```text
NAME    REFERENCE          TARGETS          MINPODS   MAXPODS   REPLICAS   AGE
scout   Deployment/scout   cpu: 1%/50%      1         5         1          11m
scout   Deployment/scout   cpu: 17%/50%     1         5         1          11m
scout   Deployment/scout   cpu: 1058%/50%   1         5         1          12m
scout   Deployment/scout   cpu: 1058%/50%   1         5         5          12m
scout   Deployment/scout   cpu: 267%/50%    1         5         5          12m
scout   Deployment/scout   cpu: 214%/50%    1         5         5          13m
scout   Deployment/scout   cpu: 48%/50%     1         5         5          13m
scout   Deployment/scout   cpu: 1%/50%      1         5         5          14m
scout   Deployment/scout   cpu: 1%/50%      1         5         4          15m
scout   Deployment/scout   cpu: 1%/50%      1         5         3          15m
scout   Deployment/scout   cpu: 1%/50%      1         5         2          15m
scout   Deployment/scout   cpu: 1%/50%      1         5         1          15m
```

Scale-up is not slowed: the replicas go from 1 to 5 in one step. After the load ends, the target falls to `1%`, but the count stays at 5 for the 60-second window. Then it falls by one pod per line: 5, 4, 3, 2, 1. Each step is one pod, as the `Pods` policy says. Compare this with the default, where the count falls from 5 to 1 in a single step after five minutes.

The window and the policy do different jobs. The window decides when the first pod may go. The policy decides how fast the rest follow. A longer window protects against short dips in load, and a small policy protects against removing capacity faster than the application can recover when load returns.

You can now read an `<unknown>` target from the `ScalingActive` condition, tell a missing request from a failing Metrics API, and set `behavior.scaleDown` with a window and a policy. You also know the defaults you change. The open question for a platform is the other half of the picture: whether the requests the HPA divides by are the right size at all.

## Common pitfalls

> [!WARNING]
> - **Setting `selectPolicy: Disabled` to "slow down" scale-down.** It turns scale-down off. The replicas never fall, and the cost stays high.
> - **Putting the window under `scaleUp` when you mean `scaleDown`.** Each direction has its own block. A scale-up window delays the reaction to load.
> - **Fixing the Deployment when the Metrics API is down.** Check `kubectl get apiservice v1beta1.metrics.k8s.io` first. When `AVAILABLE` is not `True`, no request change helps.
> - **Testing a scale-down too early.** The first pod goes only after the window has passed. Wait the full window plus one policy period before you decide the HPA is stuck.

## Your mission: Slow Down Scale-Down

You can now write a `behavior.scaleDown` section with a stabilization window and a policy. The mission gives you a working HPA for `scout` with the default scale-down. You change only the scale-down, keep the metric and the bounds, and the grader proves with a load test that the replicas stay after the load ends.

Pause the playground first:

```sh
astrona stop ats-017-playground-030-01
```

Start the mission and send it for grading:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/module-01/labs/lab-02
astrona submit -c sections/section-030/module-01/labs/lab-02
```

When you finish, remove the mission cluster and resume the playground:

```sh
astrona destroy ats-017-lab-030-01-02
astrona start ats-017-playground-030-01
```
