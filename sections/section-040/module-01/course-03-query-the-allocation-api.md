# Query The Allocation API

A cost number means nothing without two choices: which period it covers, and which objects it groups. The cost of "the last hour for each namespace" and the cost of "yesterday for each Deployment" are different questions, and a team that mixes them up compares numbers that cannot be compared. The allocation API of OpenCost makes both choices explicit, through the parameters `window` and `aggregate`.

This part sends requests to the API from the terminal. It starts with the cost of each namespace, then changes the window, the grouping and the filter, and ends with the cost of idle capacity.

## Ask for the cost of each namespace

The allocation API listens on port `9003` of the Service `opencost`. The path `/allocation/compute` returns the cost of the objects in a window. You can reach the Service through the Kubernetes API server with `kubectl get --raw`, so no `port-forward` is needed. The function `query_opencost` below wraps that call, and `jq` turns the JSON answer into one line for each namespace.

<!-- astrona:playground:renew -->

```sh
query_opencost() {
  kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?$1"
}
query_opencost 'window=1h&aggregate=namespace' | jq -r '.data[0] | to_entries[] | "\(.key) cpu=\(.value.cpuCost) ram=\(.value.ramCost) pv=\(.value.pvCost) total=\(.value.totalCost)"'
```

If the answer is empty, OpenCost has no samples yet. Wait a few minutes and run the command again. You should see something like:

```text
kube-system cpu=0.00765 ram=0.00083 pv=0 total=0.00848
local-path-storage cpu=0 ram=0.00002 pv=0 total=0.00002
monitoring cpu=0.00002 ram=0.00018 pv=0 total=0.0002
opencost cpu=0.00009 ram=0.00007 pv=0 total=0.00016
outpost cpu=0.00146 ram=0.00024 pv=0.00025 total=0.00195
starfleet cpu=0.00388 ram=0.00021 pv=0 total=0.00409
```

The answer has one entry for each namespace. Each entry splits the cost into `cpuCost`, `ramCost`, `pvCost` (the persistent volume, which is the storage) and `networkCost`, and `totalCost` is their sum. The namespace `outpost` is the only one with a storage cost, because its pod mounts the 20Gi volume `archive`. OpenCost charges the volume for its size, not for the data in it. The costs are tiny because the cluster is small and the window is short. OpenCost rounds every cost to five decimals.

## Choose the window

The parameter `window` sets the period. It takes a duration such as `30m`, `1h` or `1d`, a keyword such as `today` or `yesterday`, or a pair of times separated by a comma. A pair can be Unix timestamps in seconds or RFC 3339 dates. A request without a window fails: the API answers `BadRequest`.

A duration is aligned to the clock, so it can reach into the future. Print the window that OpenCost used for `1h`:

```sh
query_opencost 'window=1h&aggregate=namespace&filter=namespace:"starfleet"' | jq -c '.data[0].starfleet.window'
```

You should see something like:

```text
{"start":"2026-11-01T23:00:00Z","end":"2026-11-02T00:00:00Z"}
```

OpenCost answered with the whole clock hour that contains the present, from `23:00` to `00:00`. Only the part of the hour that has already passed holds data. The next hour starts a new window, so a duration always moves and its numbers change. A pair of Unix timestamps in the past is closed: OpenCost returns the same numbers every time you ask. Build a closed window of the last 10 minutes with `date`:

```sh
END=$(date -u +%s); START=$((END - 600)); echo "$START,$END"
query_opencost "window=${START},${END}&aggregate=namespace&filter=namespace:\"starfleet\"" | jq -c '.data[0].starfleet | {window, minutes, totalCost}'
```

You should see something like:

```text
1793574229,1793574829
{"window":{"start":"2026-11-01T23:03:49Z","end":"2026-11-01T23:13:49Z"},"minutes":6.18333,"totalCost":0.00192}
```

The window covers 10 minutes, but `minutes` is `6.18333`. The workload pods existed for 6.18 minutes of that window, because OpenCost had no samples before that time. The parameter `filter=namespace:"starfleet"` keeps only the entries of one namespace. Use a closed window whenever two people must get the same number, for example in a report.

## Choose the aggregate

The parameter `aggregate` sets how OpenCost groups the costs. It takes `namespace`, `controller`, `pod`, `node`, `service`, `container`, or a label as `label:<name>`. You can join several with a comma. Ask for the same namespace three ways. First by controller, with the namespace in the key, then by pod, and then by the label `app`:

```sh
query_opencost 'window=1h&aggregate=namespace,controller&filter=namespace:"starfleet"' | jq -r '.data[0] | to_entries[] | "\(.key) \(.value.totalCost)"'
query_opencost 'window=1h&aggregate=pod&filter=namespace:"starfleet"' | jq -r '.data[0] | to_entries[] | "\(.key) \(.value.totalCost)"'
query_opencost 'window=1h&aggregate=label:app&filter=namespace:"starfleet"' | jq -r '.data[0] | to_entries[] | "\(.key) \(.value.totalCost)"'
```

You should see something like:

```text
starfleet/deployment:probe 0.00039
starfleet/deployment:scout 0.00079
starfleet/deployment:scout-busy 0.00282
starfleet/deployment:shuttle 0.00009
probe-5d8ff848-x2hv7 0.00039
scout-9db9c5f65-m2xxt 0.00079
scout-busy-795ff44867-4p2qs 0.00282
shuttle-79f5897bd9-l945j 0.00009
probe 0.00039
scout 0.00079
scout-busy 0.00282
shuttle 0.00009
```

Each Deployment runs one pod, so the three groupings show the same costs under different keys. The key of a controller has the form `namespace/kind:name`. Always add the namespace when you group by controller: with `aggregate=controller` alone, the key is `deployment:probe`, and OpenCost merges the `probe` of `starfleet` with the `probe` of `outpost` into one entry. A label gives a grouping that does not depend on the owner, for example all pods of one team. The workload `scout-busy` costs the most, although it requests less than `scout`. The cost depends on what a container uses as well as on what it requests.

## Add the idle cost

The namespaces cover only what pods request or use. The nodes cost more than that, because part of each node is not requested by any pod. The parameter `includeIdle=true` adds that part as an entry named `__idle__`:

```sh
query_opencost 'window=1h&aggregate=namespace&includeIdle=true' | jq -r '.data[0] | to_entries[] | "\(.key) \(.value.totalCost)"'
```

You should see something like:

```text
__idle__ 0.02683
kube-system 0.00848
local-path-storage 0.00002
monitoring 0.0002
opencost 0.00016
outpost 0.00195
starfleet 0.0041
```

The idle entry is larger than all namespaces together. The node has far more CPU and memory than the pods request, and the node costs the same whether or not pods fill it. The idle cost is the price of unused capacity, and it is a reason to size nodes and requests with care.

OpenCost also has a web page. Run `kubectl -n opencost port-forward svc/opencost 9090:9090` in a second terminal and open `http://127.0.0.1:9090`. It shows the same allocation data as tables and charts, and it sends the same requests to the API.

You can now ask OpenCost for the cost of any period and any grouping, and you know which choices keep the numbers comparable: a closed window, the namespace in the controller key, and a filter for the objects you want. The cost of a workload is still only half of the story. The next question is how much of that cost buys capacity that the workload does not use.

## Common pitfalls

> [!WARNING]
> - **Comparing numbers from `window=1h` taken at different times.** The window moves with the clock, so the numbers change. Use a pair of Unix timestamps when two numbers must match.
> - **Using `aggregate=controller` without the namespace.** Controllers with the same name in two namespaces merge into one entry.
> - **Leaving out the window.** The API answers `BadRequest` and gives no reason.
> - **Reading `__idle__` as a workload.** It is the cost of node capacity that no pod requests. It does not belong to any namespace.
