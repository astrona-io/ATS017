# Read Efficiency And Find Waste

The workload that costs the most is not always the workload to fix first. A busy service may cost a lot because it uses a lot, and that cost is fair. A quiet service may cost less in total, but pay for capacity that it never touches. To cut waste, you need a number that compares what a workload uses with what it requests, and you need to sort by that number, not by cost.

OpenCost reports this number as **efficiency**. This part compares the usage of the playground workloads with their requests, reads the three efficiency fields, and finds out how OpenCost charges a workload that uses more than it requests.

## Compare usage with requests

Efficiency is built from the two figures that you already know how to read. The first is the usage, which `kubectl top` shows from metrics-server. The second is the request, which is part of the pod spec. Print both for the namespace `starfleet`:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet top pods
kubectl -n starfleet get pods -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory'
```

You should see something like:

```text
NAME                          CPU(cores)   MEMORY(bytes)   
probe-5d8ff848-x2hv7          1m           5Mi             
scout-9db9c5f65-m2xxt         1m           20Mi            
scout-busy-795ff44867-4p2qs   400m         109Mi           
shuttle-79f5897bd9-l945j      6m           7Mi             

POD                           CPU_REQ   MEM_REQ
probe-5d8ff848-x2hv7          50m       32Mi
scout-9db9c5f65-m2xxt         100m      64Mi
scout-busy-795ff44867-4p2qs   50m       64Mi
shuttle-79f5897bd9-l945j      10m       16Mi
```

The pod `scout` requests `100m` CPU and uses `1m`. The pod `scout-busy` requests `50m` and uses `400m`, eight times its request. Its CPU limit of `400m` stops it from using more, but nothing stops it from using more than its request. These two pods are the two ends of the range that efficiency measures.

## Read the efficiency fields

OpenCost divides usage by request for each resource. The field `cpuEfficiency` is the CPU usage divided by the CPU request. The field `ramEfficiency` is the same for memory. The field `totalEfficiency` combines the two into one number, weighted by the cost of each resource. A value near `0` means the workload uses a small share of what it reserves. A value of `1` means it uses what it requests. A value above `1` means it uses more than it requests.

Ask OpenCost for the efficiency of each Deployment in `starfleet`. The first command defines the helper that sends the request:

```sh
query_opencost() {
  kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?$1"
}
query_opencost 'window=1h&aggregate=namespace,controller&filter=namespace:"starfleet"' | jq -r '.data[0] | to_entries[] | "\(.key) cost=\(.value.totalCost) cpuEff=\(.value.cpuEfficiency) ramEff=\(.value.ramEfficiency) totalEff=\(.value.totalEfficiency)"'
```

You should see something like:

```text
starfleet/deployment:probe cost=0.00042 cpuEff=0.00139 ramEff=0.18024 totalEff=0.01521
starfleet/deployment:scout cost=0.00083 cpuEff=0.00076 ramEff=0.31059 totalEff=0.02471
starfleet/deployment:scout-busy cost=0.003 cpuEff=2.0008 ramEff=1.70409 totalEff=1.98993
starfleet/deployment:shuttle cost=0.00009 cpuEff=0.14798 ramEff=0.45599 totalEff=0.20132
```

The `scout` Deployment uses `0.08` percent of its CPU request and `31` percent of its memory request, so its `totalEfficiency` is `0.02471`. The `scout-busy` Deployment has a `cpuEfficiency` of `2.0008`: it uses about twice its request. The figure is an average over the window, so it is lower than the factor of eight in a single `kubectl top` reading. Your numbers differ a little, and they change as the window fills.

## See what OpenCost charges

The cost of `scout-busy` is the highest in the namespace, although its requests are small. The reason is the charging rule: OpenCost charges the larger of the request and the usage. Print the quantity that OpenCost charged next to the request for the two scouts:

```sh
query_opencost 'window=1h&aggregate=namespace,controller&filter=namespace:"starfleet"' | jq -c '.data[0] | to_entries[] | select(.key | test("scout")) | {controller: .key, cpuCores: .value.cpuCores, cpuCoreRequestAverage: .value.cpuCoreRequestAverage, ramBytes: .value.ramBytes, ramByteRequestAverage: .value.ramByteRequestAverage}'
```

You should see something like:

```text
{"controller":"starfleet/deployment:scout","cpuCores":0.1,"cpuCoreRequestAverage":0.1,"ramBytes":67108864,"ramByteRequestAverage":67108864}
{"controller":"starfleet/deployment:scout-busy","cpuCores":0.37496,"cpuCoreRequestAverage":0.05,"ramBytes":114298002.28571,"ramByteRequestAverage":67108864}
```

For `scout`, the charged quantity equals the request, because the usage is smaller. For `scout-busy`, OpenCost charged `0.37496` cores and about `109Mi` of memory, which is more than the requests of `0.05` cores and `64Mi`. The charge follows the usage. A request that is too low does not make a workload cheaper. It only moves the cost from the request to the usage, and it puts the pod at risk, because the scheduler placed it as if it needed only `50m`.

## Sort by efficiency, not by cost

A list sorted by cost shows where the money goes. A list sorted by efficiency shows where the waste is. Run the query for all namespaces, drop the entries that cost nothing, and sort by `totalEfficiency`:

```sh
query_opencost 'window=1h&aggregate=namespace,controller' | jq -r '[.data[0] | to_entries[] | select(.value.totalCost > 0)] | sort_by(.value.totalEfficiency) | .[] | "\(.key) \(.value.totalEfficiency) \(.value.totalCost)"'
```

You should see something like the following. The output is shortened to the first and the last lines:

```text
outpost/deployment:probe 0.00113 0.00206
starfleet/deployment:probe 0.01521 0.00042
...
monitoring/deployment:prometheus-server 1 0.00018
starfleet/deployment:scout-busy 1.98993 0.003
```

The Deployment `probe` in `outpost` is the least efficient, with a `totalEfficiency` of `0.00113`. It requests `200m` CPU and `256Mi` of memory and uses almost nothing, and it mounts a 20Gi volume. Its total cost is close to the cost of `scout-busy`. The Deployment `scout-busy` costs the most and has the highest efficiency. A team that sorts by cost would shrink the busiest workload, which is the wrong one. The entries with efficiency `1`, such as `prometheus-server`, have no requests in this cluster, so there is nothing to compare, and OpenCost reports `1`.

You can now read the three efficiency fields, explain why a workload that uses more than it requests costs more than its request, and rank workloads by waste. Efficiency tells you where to look. It does not tell you the right size, because it comes from one window of usage. A real right-sizing decision needs a long window that includes the busiest time.

## Common pitfalls

> [!WARNING]
> - **Sorting by cost.** The workload that costs the most is often the one that uses what it requests. Sort by `totalEfficiency` to find waste.
> - **Reading an efficiency above `1` as good.** It means the usage is above the request. The pod is at risk of throttling or eviction, and the scheduler counted too little for it.
> - **Trusting an efficiency of `1`.** A workload without requests shows `1`, because there is no request to compare. Check the requests before you trust the figure.
> - **Right-sizing from a short window.** A window of a few minutes misses the busy hours. Look at a long window before you lower a request.
