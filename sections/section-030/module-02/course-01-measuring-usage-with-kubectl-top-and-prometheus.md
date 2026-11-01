# Measuring Usage With kubectl top And Prometheus

You cannot size a workload without knowing what it uses. A guess made at deployment time is usually wrong, and nobody notices because the pod still runs. This part measures the usage of the two example workloads in two ways: the value right now, and the values over time. It also shows why one reading is not enough to choose a request.

## Compare requests with usage now

Two numbers describe every container: what it requests and what it uses. The scheduler reads the request. The kubelet measures the usage, and metrics-server serves it to `kubectl top`. Start with the requests that each pod asks for.

<!-- astrona:playground:renew -->

Print the requests and the memory limit of each pod:

```sh
kubectl -n starfleet get pods -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,MEM_LIM:.spec.containers[0].resources.limits.memory'
```

You should see something like:

```text
POD                                       CPU_REQ   MEM_REQ   MEM_LIM
scout-overprovisioned-786cfdfb8d-tsdqw    1         1Gi       1Gi
scout-underprovisioned-7f6bcf55b7-xmxdg   20m       32Mi      512Mi
shuttle-7b8bd75595-hkdhf                  10m       16Mi      32Mi
```

Now read the usage of the same containers. The option `--containers` shows one line for each container instead of one for each pod:

```sh
kubectl -n starfleet top pods --containers
```

You should see something like (the numbers move a little from run to run):

```text
POD                                       NAME      CPU(cores)   MEMORY(bytes)
scout-overprovisioned-786cfdfb8d-tsdqw    scout     2m           22Mi
scout-underprovisioned-7f6bcf55b7-xmxdg   scout     2m           165Mi
shuttle-7b8bd75595-hkdhf                  shuttle   29m          0Mi
```

The two tables tell a clear story. `scout-overprovisioned` requests `1` CPU and `1Gi` of memory, and it uses `2m` and `22Mi`. That is about 500 times the CPU and 45 times the memory it needs. `scout-underprovisioned` is the opposite for memory: it requests `32Mi` and uses `165Mi`. It runs only because its limit is `512Mi`. A pod that uses five times its memory request is the first to be evicted when the node runs short of memory.

The scheduler does not see usage at all. It adds up requests. Ask the node what it has handed out:

```sh
kubectl describe node | sed -n '/Allocated resources/,/memory/p'
```

You should see something like:

```text
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests     Limits
  --------           --------     ------
  cpu                2080m (34%)  0 (0%)
  memory             1562Mi (7%)  1908Mi (8%)
```

The `Requests` column includes the system pods of the cluster. More than half of the `2080m` CPU is the `1` CPU that `scout-overprovisioned` reserves and never uses. On a real node pool that unused reservation is capacity that no other pod can get.

## Read usage over time

`kubectl top` shows one value: the latest sample. A workload that is quiet now may peak every hour. A request chosen from one sample would be too low at the peak. To choose a request you need the usage over a period, and that needs a system that stores samples.

**Prometheus** is a time-series database. It scrapes metrics from targets at a fixed interval, stores every sample with a timestamp, and answers queries written in **PromQL**, its query language. In this playground a small Prometheus scrapes the kubelet's **cAdvisor** endpoint every 15 seconds. cAdvisor is the part of the kubelet that measures the resource usage of every container.

Two cAdvisor metrics matter for right-sizing. `container_memory_working_set_bytes` is the memory a container uses and the kernel cannot easily take back. The kubelet compares this value with the memory limit, and `kubectl top` shows the same figure. `container_cpu_usage_seconds_total` is a counter of the CPU time that the container has used since it started. A counter only grows, so you ask for its rate: `rate(...[1m])` is the number of CPU seconds used per second over the last minute, which is the same as the number of CPU cores in use.

Define a small shell function that sends a PromQL query to Prometheus from the `shuttle` pod and prints the JSON answer:

```sh
query_prometheus() {
  kubectl -n starfleet exec deploy/shuttle -- \
    curl -s --get http://prometheus-server.monitoring.svc/api/v1/query \
    --data-urlencode "query=$1"
  echo
}
```

First ask for the memory working set of the `scout` containers. `sum by (pod)` adds up the series of each pod, so you get one value for each pod:

```sh
query_prometheus 'sum by (pod) (container_memory_working_set_bytes{namespace="starfleet",container="scout"})'
```

You should see something like (one line in the terminal):

```text
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"pod":"scout-overprovisioned-786cfdfb8d-tsdqw"},"value":[1793566806.937,"23388160"]},{"metric":{"pod":"scout-underprovisioned-7f6bcf55b7-xmxdg"},"value":[1793566806.937,"173715456"]}]}}
```

Each `value` has a timestamp and the memory in bytes. `23388160` bytes is about `22Mi` and `173715456` bytes is about `166Mi`. These match `kubectl top` within a few mebibytes, because both read the same cAdvisor figure at slightly different moments. Now ask for the CPU in cores:

```sh
query_prometheus 'sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="starfleet",container="scout"}[1m]))'
```

You should see something like (one line in the terminal):

```text
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"pod":"scout-overprovisioned-786cfdfb8d-tsdqw"},"value":[1793566807.002,"0.0014212007998316138"]},{"metric":{"pod":"scout-underprovisioned-7f6bcf55b7-xmxdg"},"value":[1793566807.002,"0.0013945587475878585"]}]}}
```

The value `0.00142` cores is `1.4m`. Prometheus has a better resolution than `kubectl top`, which rounds to whole millicores. Both queries are instant queries: they answer for this moment only. You now have two ways to read usage: one latest value, and a stored history. The open question is how to turn a history into one number for a request, and how much headroom to add on top of it.

## Common pitfalls

> [!WARNING]
> - **Choosing a request from one `kubectl top` reading.** It is the latest sample. A workload with a daily peak looks quiet most of the day. Query a period that includes the peak.
> - **Comparing usage with the limit and not with the request.** The scheduler and the HPA read requests. A pod that uses far more than it requests is exposed to eviction even when it is below its limit.
> - **Reading the CPU counter without `rate()`.** `container_cpu_usage_seconds_total` is a total in seconds. Only `rate()` turns it into cores.
> - **Querying before Prometheus has samples.** Wait a few minutes after the playground starts. A new pod needs about a minute before `kubectl top` shows it.
