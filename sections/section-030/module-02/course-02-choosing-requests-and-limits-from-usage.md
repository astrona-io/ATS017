# Choosing Requests And Limits From Usage

A measurement is not yet a request. A request must cover the busiest moment of the workload, plus some room for a busier moment than the one you measured. This part turns the usage history of the two `scout` workloads into new numbers, applies them to a Deployment, and checks the result.

## From a series of samples to one number

Prometheus can answer a question about a period. A **subquery** such as `[5m:15s]` evaluates an inner expression every 15 seconds for the last five minutes. An outer function such as `max_over_time` then reduces those values to one number. The result is the peak of the period.

Ask for the peak memory of each `scout` pod over the last five minutes. The shell function `query_prometheus` below sends a PromQL query to Prometheus from the `shuttle` pod. Define it once for the shell session.

<!-- astrona:playground:renew -->

```sh
query_prometheus() {
  kubectl -n starfleet exec deploy/shuttle -- \
    curl -s --get http://prometheus-server.monitoring.svc/api/v1/query \
    --data-urlencode "query=$1"
  echo
}
query_prometheus 'max_over_time(sum by (pod) (container_memory_working_set_bytes{namespace="starfleet",container="scout"})[5m:15s])'
```

You should see something like (one line in the terminal):

```text
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"pod":"scout-overprovisioned-786cfdfb8d-tsdqw"},"value":[1793566807.068,"24530944"]},{"metric":{"pod":"scout-underprovisioned-7f6bcf55b7-xmxdg"},"value":[1793566807.068,"174546944"]}]}}
```

The peak is `24530944` bytes (about `23Mi`) for `scout-overprovisioned` and `174546944` bytes (about `166Mi`) for `scout-underprovisioned`. Now ask for the peak CPU in cores, with the same subquery around the `rate()`:

```sh
query_prometheus 'max_over_time(sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="starfleet",container="scout"}[1m]))[5m:15s])'
```

You should see something like (one line in the terminal):

```text
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"pod":"scout-overprovisioned-786cfdfb8d-tsdqw"},"value":[1793566807.134,"0.001877178191674073"]},{"metric":{"pod":"scout-underprovisioned-7f6bcf55b7-xmxdg"},"value":[1793566807.134,"0.0017297569358796488"]}]}}
```

The peak CPU is about `1.9m` and `1.7m`. For a workload with a spiky load, the maximum can come from one rare spike. In that case use `quantile_over_time(0.95, ...)` in place of `max_over_time`. The 95th percentile is the value that the usage stays below 95 percent of the time, so it ignores the highest 5 percent of the samples.

## Rules for the numbers

Memory and CPU need different rules, because the kernel treats them differently. A container that goes over its CPU limit is **throttled**, which makes it slower. A container that goes over its memory limit is killed with `OOMKilled`. A memory limit must therefore never sit below the real peak.

The rules this course uses are simple, and the exam accepts any reasonable values that cover the measured usage:

- **Memory request**: the peak working set plus about 25 percent, rounded up to the next `32Mi`.
- **Memory limit**: equal to the memory request. The pod has a fixed memory ceiling, and the node cannot be asked for more memory than the pod reserved. Because the CPU has a request but no limit, the QoS class is `Burstable`.
- **CPU request**: the 95th percentile (or the peak) plus about 30 percent, with a floor of `10m`. Both scouts use less than `2m`, so they get the floor.
- **CPU limit**: none. A CPU limit only throttles the container, and unused CPU on the node helps nobody.

Apply the rules to `scout-underprovisioned`. Its peak is about `166Mi`, so the request is `166 × 1.25 = 208`, rounded up to `224Mi`. The command `kubectl set resources` changes the Deployment template, which creates a new pod:

```sh
kubectl -n starfleet set resources deployment/scout-underprovisioned \
  --requests=cpu=10m,memory=224Mi --limits=memory=224Mi
kubectl -n starfleet rollout status deployment/scout-underprovisioned
```

You should see something like (the number of `Waiting` lines varies):

```text
deployment.apps/scout-underprovisioned resource requirements updated
Waiting for deployment "scout-underprovisioned" rollout to finish: 1 old replicas are pending termination...
deployment "scout-underprovisioned" successfully rolled out
```

Check the new pod. The Deployment controller starts the new pod before it removes the old one, so this command can show both pods for a few seconds:

```sh
kubectl -n starfleet get pods -l app=scout-underprovisioned -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,MEM_LIM:.spec.containers[0].resources.limits.memory,QOS:.status.qosClass,RESTARTS:.status.containerStatuses[0].restartCount'
```

You should see something like:

```text
POD                                       CPU_REQ   MEM_REQ   MEM_LIM   QOS         RESTARTS
scout-underprovisioned-7f6bcf55b7-xmxdg   20m       32Mi      512Mi     Burstable   0
scout-underprovisioned-7f9bd47dfc-c7fmp   10m       224Mi     224Mi     Burstable   0
```

The first line is the old pod, which is still terminating. The second line is the new pod with the new numbers. Last, compare the new request with the usage:

```sh
kubectl -n starfleet top pods -l app=scout-underprovisioned
```

You should see something like:

```text
NAME                                      CPU(cores)   MEMORY(bytes)
scout-underprovisioned-7f9bd47dfc-c7fmp   2m           160Mi
```

The pod uses `160Mi` and requests `224Mi`, so it has about 40 percent headroom for a busier moment. The memory request is now above the usage, so the kubelet no longer treats the pod as a candidate for eviction before the other pods. The limit equals the request, so the kernel will only kill the container if its memory grows past `224Mi`.

The same rules apply to `scout-overprovisioned`, but there the numbers go down. Its peak memory is `23Mi`, so the request rounds up to `32Mi`, and its CPU request is the `10m` floor. The pod that runs it can take these numbers without being replaced, as the next steps show.

You can now turn a usage history into a request: take the peak or a high percentile, add headroom, round up, and set the memory limit equal to the request. Applying the values through the Deployment template works, but it replaces the pod. The question that remains is how to change the resources of a pod that must keep running.

## Common pitfalls

> [!WARNING]
> - **A memory limit below the real peak.** The kernel kills the container with `OOMKilled` and the pod restarts again and again. Measure the peak before you lower a limit.
> - **Adding a CPU limit "to be safe".** A CPU limit throttles the container at the limit, even when the node has free CPU. Set a CPU request and leave the limit out unless the platform requires one.
> - **Sizing from a quiet period.** A request taken from the idle night hours is too low for the day. Query a period that includes the busiest time.
> - **No headroom.** A request equal to the peak leaves nothing for a busier moment. Add 20 to 30 percent.

## Your mission: Right-Size From Measured Usage

You can now read the usage of a workload and turn it into a request and a memory limit. The mission gives you two Deployments with wrong resources: one asks for far too much, and the other is killed again and again with `OOMKilled`. You measure both, set new values in the Deployments, and keep the second pod from restarting.

Pause the playground first:

```sh
astrona stop ats-017-playground-030-02
```

Start the mission and send it for grading:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/module-02/labs/lab-01
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When you finish, remove the mission cluster and resume the playground:

```sh
astrona destroy ats-017-lab-030-02-01
astrona start ats-017-playground-030-02
```
