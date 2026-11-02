# Find Idle And Shared Cost

The costs of the teams do not add up to the cost of the cluster. A node costs money for every hour it runs, whether pods use its capacity or not. The part of the node that no pod requests belongs to no team, and a report that ignores it understates the bill.

This part adds that part to the report, shows how to share it between the teams, and then uses the efficiency figures to pick the workload to right-size. It ends with the measurement that matters: what happens to the cost of a workload and to the idle cost after you lower a request.

## Add the idle cost

**Idle cost** is the cost of node capacity that no pod requests. OpenCost computes it as the price of the nodes minus the cost of everything that pods request or use. The parameter `includeIdle=true` adds it to the answer as an entry named `__idle__`. First look at the size of the node, so you know what idle capacity means in this cluster:

<!-- astrona:playground:renew -->

```sh
kubectl get nodes -o jsonpath='{.items[0].status.allocatable.cpu}{" "}{.items[0].status.allocatable.memory}{"\n"}'
```

You should see something like:

```text
6 22841640Ki
```

The node offers 6 CPU cores and about 21.8 GiB of memory. The pods of the playground request a small part of that. Define the helper function and the variables for a closed window of 5 minutes that ends 3 minutes ago, because OpenCost trails Prometheus. Store the window in `BEFORE_WINDOW`, because you compare it with a later window at the end of this part. Then ask for the cost of each namespace with the idle cost:

```sh
query_opencost() {
  kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?$1"
}
END=$(( $(date -u +%s) - 180 )); START=$((END - 300)); BEFORE_WINDOW="${START},${END}"
query_opencost "window=${BEFORE_WINDOW}&aggregate=namespace&includeIdle=true" | jq -r '.data[0] | to_entries[] | "\(.key) total=\(.value.totalCost)"'
```

You should see something like:

```text
__idle__ total=0.01243
kube-system total=0.00255
local-path-storage total=0
monitoring total=0.00005
opencost total=0.00008
outpost total=0.0005
starfleet total=0.00397
```

The entry `__idle__` is the largest of all. It costs more than the namespaces `starfleet` and `outpost` together, because the node is large and the workloads request little. The costs of the namespaces plus `__idle__` add up to the cost of the node for the window.

## Share the idle cost between the teams

A report that shows `__idle__` as its own line is honest, but it gives no team a reason to act. The parameter `shareIdle=true` removes the entry `__idle__` and adds its cost to the other entries, in proportion to their CPU and memory cost. Each team then carries a part of the capacity that nobody requests. The parameter works together with `includeIdle=true`. Without `includeIdle=true`, it changes nothing.

```sh
query_opencost "window=${BEFORE_WINDOW}&aggregate=label:team&includeIdle=true&shareIdle=true" | jq -r '.data[0] | to_entries[] | "\(.key) total=\(.value.totalCost)"'
```

You should see something like:

```text
__unallocated__ total=0.00851
navigation total=0.00101
research total=0.00062
science total=0.00944
```

The team `science` carries the largest share of the idle cost, because it has the largest cost to begin with. Do not add the `filter` parameter to a query that shares idle cost. A filter by namespace removes `__idle__` before OpenCost shares it, and the totals then stay as they were. The parameter `shareNamespaces` is documented for sharing the cost of whole namespaces, but OpenCost 1.121.3 ignores it: the totals are the same with and without it.

## Pick the workload to right-size

Idle cost shrinks when requests match usage. Efficiency tells you which requests are too big. Sort the Deployments of the two namespaces by `totalEfficiency`, the lowest first:

```sh
query_opencost "window=${BEFORE_WINDOW}&aggregate=namespace,controller&filter=namespace:%22starfleet%22,%22outpost%22" | jq -r '[.data[0] | to_entries[]] | sort_by(.value.totalEfficiency) | .[] | "\(.key) eff=\(.value.totalEfficiency) total=\(.value.totalCost)"'
```

You should see something like:

```text
outpost/__unallocated__ eff=0 total=0
outpost/deployment:archive eff=0.00084 total=0.00026
starfleet/deployment:scout-overprovisioned eff=0.00109 total=0.00359
outpost/deployment:probe eff=0.00233 total=0.00024
starfleet/deployment:probe eff=0.02019 total=0.00012
starfleet/deployment:scout eff=0.02859 total=0.00024
starfleet/deployment:shuttle eff=0.57296 total=0.00003
```

The first Deployment, `archive`, has the lowest efficiency. The second, `scout-overprovisioned`, costs about fourteen times more. The money you can save is the cost times the unused share, which is `totalCost * (1 - totalEfficiency)`. For `archive` that is about `0.00026`, and for `scout-overprovisioned` it is about `0.00358`. The right workload to change first is the one with the largest wasted cost, not the one with the lowest ratio. Compare the request with the real usage:

```sh
kubectl -n starfleet get deployment scout-overprovisioned -o json | jq -c '.spec.template.spec.containers[0].resources'
kubectl -n starfleet top pods
```

You should see something like:

```text
{"requests":{"cpu":"1500m","memory":"1Gi"}}
NAME                                    CPU(cores)   MEMORY(bytes)   
probe-6c7d76fc97-clkw9                  1m           6Mi             
scout-5c59564ccb-ng5p2                  1m           21Mi            
scout-overprovisioned-d4458fdf8-fhkjz   1m           17Mi            
shuttle-f54cf888-wbsfg                  7m           6Mi             
```

The pod `scout-overprovisioned` uses `1m` CPU and `17Mi` memory and requests `1500m` and `1Gi`. It reserves about a thousand times its CPU usage. Metrics-server provides the usage for `kubectl top`. The request that fits is the usage plus a margin, so `50m` and `64Mi` leave room for a burst without wasting the node.

## Lower the request and read the effect

Now change the request. The command `kubectl set resources` edits the pod template, so the Deployment controller starts a new pod with the new requests:

```sh
kubectl -n starfleet set resources deployment/scout-overprovisioned --requests=cpu=50m,memory=64Mi
kubectl -n starfleet rollout status deployment/scout-overprovisioned
```

You should see:

```text
deployment.apps/scout-overprovisioned resource requirements updated
deployment "scout-overprovisioned" successfully rolled out
```

Now wait about 8 minutes. OpenCost needs the time to collect samples of the new pod. Then ask for a window that starts after the change. The jq expression divides each cost by the `minutes` field and multiplies by 60. It turns two windows of different lengths into a cost per hour, so you can compare them. Store the new window in `AFTER_WINDOW` and compare the idle cost and the namespace `starfleet` in both:

```sh
END=$(( $(date -u +%s) - 180 )); START=$((END - 300)); AFTER_WINDOW="${START},${END}"
for window in "${BEFORE_WINDOW}" "${AFTER_WINDOW}"; do
  query_opencost "window=${window}&aggregate=namespace&includeIdle=true" | jq -r '.data[0] | to_entries[] | select(.key == "__idle__" or .key == "starfleet") | "\(.key) per_hour=\(.value.totalCost / .value.minutes * 60 * 10000 | round / 10000)"'
done
```

You should see something like the first two lines for the window before the change, and the last two for the window after it:

```text
__idle__ per_hour=0.179
starfleet per_hour=0.0572
__idle__ per_hour=0.222
starfleet per_hour=0.0074
```

The cost of `starfleet` fell from `0.0572` to `0.0074` dollars an hour, and the idle cost rose from `0.179` to `0.222`. The node costs the same, so the capacity that the workload no longer requests became idle. The two changes are close but not equal, because OpenCost rounds each cost to five decimals and the windows are short. The efficiency of the Deployment shows the same change: it rose from `0.00109` to `0.0385`.

The saving is real only when the freed capacity goes somewhere. On one node, the money is still spent. On a cluster with several nodes, a smaller sum of requests lets you remove a node, and the bill falls.

You can now add idle cost to a report, share it between teams, choose the workload with the largest waste and prove the effect of a smaller request. The last step is to do it yourself: lower a request and prove the effect.

## Common pitfalls

> [!WARNING]
> - **Sharing idle cost without `includeIdle=true`.** `shareIdle=true` alone changes nothing. Use both parameters.
> - **Filtering a query that shares idle cost.** A filter by namespace removes `__idle__` before it is shared, so the totals do not change. Share idle cost on the whole cluster.
> - **Ranking by efficiency alone.** A cheap workload with a tiny request has a low ratio and saves little. Multiply the cost by the unused share to see the money.
> - **Expecting a lower bill from a smaller request on one node.** The cost moves to `__idle__`. The bill falls only when you remove capacity.
> - **Comparing windows of different lengths.** Divide by `minutes` and multiply by 60 to get a cost per hour.

## Your mission: Cut Idle Cost By Right-Sizing

You can now find the workload that wastes the most of its request and lower the request so it fits. The mission gives you four Deployments in `starfleet`. One of them requests far more than it uses, and another one uses everything it requests. You change only the first.

Pause the playground first:

```sh
astrona stop ats-017-playground-040-02
```

Start the mission and send it for grading. The start-up takes about 10 minutes, because the script waits until OpenCost has data:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-02/labs/lab-02
astrona submit -c sections/section-040/module-02/labs/lab-02
```

When you finish, remove the mission cluster and resume the playground:

```sh
astrona destroy ats-017-lab-040-02-02
astrona start ats-017-playground-040-02
```
