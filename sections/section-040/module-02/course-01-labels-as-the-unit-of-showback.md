# Labels As The Unit Of Showback

A finance team does not ask what a namespace costs. It asks what a team costs, and a team does not always match a namespace. One team can run workloads in three namespaces, and one namespace can hold the workloads of three teams. If the report cannot follow the team, nobody can act on it.

This part shows how OpenCost follows a team: through a label on the pods. It explains the two ways to use that number, shows exactly where the label must be set, and then asks OpenCost for the cost of each team and finds the part that belongs to nobody.

## Showback and chargeback

**Showback** is a report that shows each team what its workloads cost. Nobody pays from it. The report makes the cost visible, so the team can decide what to change. **Chargeback** goes one step further: the cost of each team is moved to the budget of that team. Both need the same input, which is a reliable owner for every dollar.

In Kubernetes, the owner is a label. The label key is a convention that the organisation picks. This module uses `team`, with the values `navigation`, `science`, `research` and `operations`. OpenCost does not know what a team is. It only groups cost by the value of a label key that you choose in the query.

## Where OpenCost reads the label

OpenCost reads labels from pods, not from Deployments. A Deployment has two places for labels. The field `metadata.labels` labels the Deployment object. The field `spec.template.metadata.labels` is the template for the labels of every pod that the Deployment creates. Only the second one reaches the pods, so only the second one counts for cost.

First list the Deployments with the value of their `team` label as an extra column. The `-L` flag of `kubectl get` adds a column for a label key.

<!-- astrona:playground:renew -->

```sh
kubectl get deploy -A -L team
```

You should see something like the output below. The rows of the system namespaces (`kube-system`, `monitoring`, `opencost` and `local-path-storage`) are left out:

```text
NAMESPACE            NAME                            READY   UP-TO-DATE   AVAILABLE   AGE   TEAM
outpost              archive                         1/1     1            1           26m   
outpost              probe                           1/1     1            1           26m   research
starfleet            probe                           1/1     1            1           26m   navigation
starfleet            scout                           1/1     1            1           26m   navigation
starfleet            scout-overprovisioned           1/1     1            1           26m   science
starfleet            shuttle                         1/1     1            1           26m   navigation
```

The Deployment `archive` in the namespace `outpost` has an empty `TEAM` column. Look at the two label places of `scout`, which is a Deployment that has the label:

```sh
kubectl -n starfleet get deploy scout -o json | jq -c '{deployment_labels: .metadata.labels, pod_template_labels: .spec.template.metadata.labels}'
```

You should see:

```text
{"deployment_labels":{"app":"scout","team":"navigation"},"pod_template_labels":{"app":"scout","team":"navigation"}}
```

Both places carry `team: navigation` here. The pod template is the one that matters. A Deployment that has the label only on its own metadata creates pods without the label, and OpenCost attributes their cost to nobody.

## See the label in Prometheus

OpenCost gets pod labels from Prometheus. The metric `kube_pod_labels` has one series for each pod, and every label of the pod becomes a metric label with the prefix `label_`. In this playground the series comes from OpenCost itself, which exports it on port `9003`, so the Prometheus job is `opencost`. Define the function `query_prometheus` and ask for the pod of `scout`:

```sh
query_prometheus() {
  kubectl -n starfleet exec deploy/shuttle -- \
    curl -s --get http://prometheus-server.monitoring.svc/api/v1/query \
    --data-urlencode "query=$1"
}
query_prometheus 'kube_pod_labels{namespace="starfleet",pod=~"scout-[a-z0-9]+-[a-z0-9]+"}' | jq -c '.data.result[].metric'
```

You should see something like:

```text
{"__name__":"kube_pod_labels","instance":"10.96.143.186:9003","job":"opencost","label_app":"scout","label_pod_template_hash":"5c59564ccb","label_team":"navigation","namespace":"starfleet","pod":"scout-5c59564ccb-ng5p2","uid":"346c7bae-2d5e-410d-8b41-820ac0097673"}
```

The label `label_team` has the value `navigation`. When you ask OpenCost for `aggregate=label:team`, it reads exactly this metric label. The metric exists only for pods that exist. A pod that starts later appears in `kube_pod_labels` at the next scrape, which is why a new label takes a few minutes to show up in the cost.

## Find the cost without an owner

Now ask OpenCost for the cost of each team. The function `query_opencost` below calls the allocation API of OpenCost through the Kubernetes API server. The variables `START` and `END` build a closed window of the last 10 minutes, so the numbers do not move while you read them.

```sh
query_opencost() {
  kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?$1"
}
END=$(date -u +%s); START=$((END - 600))
query_opencost "window=${START},${END}&aggregate=label:team" | jq -r '.data[0] | to_entries[] | "\(.key) total=\(.value.totalCost) eff=\(.value.totalEfficiency)"'
```

If the answer is empty, OpenCost has no samples yet. Wait a few minutes and run the command again. You should see something like:

```text
__unallocated__ total=0.00294 eff=0.14246
navigation total=0.00038 eff=0.06368
research total=0.00024 eff=0.00233
science total=0.00359 eff=0.00109
```

OpenCost put the cost of every pod without a `team` label into one entry named `__unallocated__`. It holds two kinds of cost: the pods of your workloads that miss the label, and the system pods of the cluster, which also have no `team` label. To see only your workloads, add a filter. The parameter `filter=namespace:"starfleet","outpost"` keeps the entries of two namespaces. The `%22` below is the URL encoding of the quote character:

```sh
query_opencost "window=${START},${END}&aggregate=label:team&filter=namespace:%22starfleet%22,%22outpost%22" | jq -r '.data[0] | to_entries[] | "\(.key) total=\(.value.totalCost) eff=\(.value.totalEfficiency)"'
```

You should see something like:

```text
__unallocated__ total=0.00026 eff=0.00084
navigation total=0.00038 eff=0.06368
research total=0.00024 eff=0.00233
science total=0.00359 eff=0.00109
```

The three teams have the same cost as before, but `__unallocated__` fell from `0.00294` to `0.00026`. The difference of `0.00268` was the cost of `kube-system`, `monitoring`, `opencost` and `local-path-storage`. What is left, `0.00026`, is the Deployment `archive`: it runs in `outpost`, it has no label, and it requests three times the CPU of the `research` workload. Nobody owns that cost, so nobody will lower it.

You now know that OpenCost groups cost by the labels of pods, that the pod template is the place to set them, and that `__unallocated__` is the list of workloads to fix. The open question is how to read the same cost along other axes, namespace and controller, and how to repair the missing label so that `archive` moves to a team.

## Common pitfalls

> [!WARNING]
> - **Putting the label only on the Deployment.** The field `metadata.labels` of a Deployment does not reach its pods. Set the label under `spec.template.metadata.labels`.
> - **Reading `__unallocated__` as one problem.** It holds your unlabelled workloads and the system namespaces. Filter by namespace before you decide that a workload has no owner.
> - **Expecting a new label at once.** OpenCost reads labels from Prometheus, which scrapes once a minute. A pod that starts with a new label shows under its team after about five minutes.
> - **Using a window that moves.** A duration such as `1h` changes while time passes. Use a pair of Unix timestamps when two people must see the same number.
