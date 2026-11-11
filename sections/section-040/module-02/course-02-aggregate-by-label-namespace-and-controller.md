# Aggregate By Label, Namespace And Controller

A single grouping hides things. The cost of a team does not tell you which namespace holds it, and the cost of a namespace does not tell you which team owns it. The allocation API of OpenCost lets you join several groupings in one query, so you can look at the same cost along more than one axis.

This part joins the team label with the namespace and with the controller, uses the result to find the workload that has no team, fixes its label, and then shows when the fix appears in the report and when it does not. It ends with a mission that asks you to do the same work on a fresh cluster.

## Join the label with the namespace

The parameter `aggregate` takes a comma-separated list. With `aggregate=namespace,label:team`, OpenCost builds one entry for each pair of namespace and team, and the key has the form `namespace/team`. The function `query_opencost` below calls the allocation API through the Kubernetes API server. The variables `START` and `END` build a closed window of 5 minutes. OpenCost trails Prometheus by a few minutes, so the window below ends 3 minutes in the past.

<!-- astrona:playground:renew -->

```sh
query_opencost() {
  kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?$1"
}
END=$(( $(date -u +%s) - 180 )); START=$((END - 300)); BEFORE_WINDOW="${START},${END}"
query_opencost "window=${BEFORE_WINDOW}&aggregate=namespace,label:team&filter=namespace:%22starfleet%22,%22outpost%22" | jq -r '.data[0] | to_entries[] | "\(.key) total=\(.value.totalCost) eff=\(.value.totalEfficiency)"'
```

If the answer is empty, wait a few minutes and run the command again. Before you change anything, you should see something like:

```text
outpost/__unallocated__ total=0.00026 eff=0.00084
outpost/research total=0.00024 eff=0.00233
starfleet/navigation total=0.00038 eff=0.06368
starfleet/science total=0.00359 eff=0.00109
```

The entry `outpost/__unallocated__` is the cost of `archive`. The pair of namespace and team shows both facts at once: the cost has no owner, and it sits in the namespace `outpost`. Another team could own it, and the report would not tell you. The team has to come from the pods.

## Add the missing label

The fix is to put `team: operations` into the pod template of the Deployment `archive`. You could use `kubectl edit`, but a patch file is easier to repeat and to review. Save this as `deployment-patch-archive-team.yaml`:

```yaml
spec:
  template:
    metadata:
      labels:
        team: operations
```

Apply it with `kubectl patch`. A patch merges its content into the Deployment, so the other fields stay as they are. Record the time first, because you need it later to ask for the cost since the change:

```sh
PATCHED_AT=$(date -u +%s)
kubectl -n outpost patch deployment archive --patch-file deployment-patch-archive-team.yaml
```

You should see:

```text
deployment.apps/archive patched
```

Then check the result. A change to the pod template makes the Deployment controller start a new pod and stop the old one. Wait for the rollout to finish and list the pods with the `team` label as a column:

```sh
kubectl -n outpost rollout status deployment/archive
kubectl -n outpost get pods -L team
```

You should see something like:

```text
deployment "archive" successfully rolled out
NAME                       READY   STATUS    RESTARTS   AGE   TEAM
archive-54fb6dc9df-spzr4   1/1     Running   0          12m   operations
probe-6bb45869cf-hsgsm     1/1     Running   0          41m   research
```

The new pod of `archive` carries `team=operations`. The Deployment controller replaces the pod, because a pod keeps the labels it was created with.

## Wait for OpenCost to see the new pod

OpenCost does not see the new pod at once. Prometheus scrapes `kube_pod_labels` every minute, and OpenCost trails Prometheus by a few minutes. After about five minutes, ask for the cost of each pod and team since the patch. The pair `pod,label:team` shows the old and the new pod of `archive` side by side:

```sh
query_opencost "window=${PATCHED_AT},$(date -u +%s)&aggregate=pod,label:team&filter=namespace:%22outpost%22" | jq -r '.data[0] | keys[]'
```

You should see something like:

```text
archive-54fb6dc9df-spzr4/operations
archive-5ccc47f8db-gbz9f/__unallocated__
probe-6bb45869cf-hsgsm/research
```

The old pod `archive-5ccc47f8db-gbz9f` ran before the patch, so it stays under `__unallocated__`. The new pod runs under `operations`. If the new pod does not appear under `operations`, wait one more minute and run the command again.

## See that history does not change

A closed window returns the same numbers every time, and that includes the attribution. Ask again for the window that you stored in `BEFORE_WINDOW` before the patch:

```sh
query_opencost "window=${BEFORE_WINDOW}&aggregate=label:team&filter=namespace:%22starfleet%22,%22outpost%22" | jq -r '.data[0] | to_entries[] | "\(.key) total=\(.value.totalCost) eff=\(.value.totalEfficiency)"'
```

You should see something like:

```text
__unallocated__ total=0.00026 eff=0.00084
navigation total=0.00038 eff=0.06368
research total=0.00024 eff=0.00233
science total=0.00359 eff=0.00109
```

The entry `__unallocated__` is still there. The pods that ran in that window had no label, and OpenCost does not rewrite history. A label fix improves the report from the moment the new pod starts. To compare two periods fairly, ask for a window that starts after OpenCost sees the new pod.

## Read the cost of each controller and team

Ask for a window that starts after the new pod appeared, and group by controller and team. The key has the form `deployment:name/team`. The key has no namespace, so two Deployments with the same name in different namespaces get separate entries only when their teams differ.

```sh
END=$(( $(date -u +%s) - 180 )); START=$((END - 300))
query_opencost "window=${START},${END}&aggregate=controller,label:team&filter=namespace:%22starfleet%22,%22outpost%22" | jq -r '.data[0] | to_entries[] | "\(.key) total=\(.value.totalCost) eff=\(.value.totalEfficiency)"'
```

You should see something like:

```text
deployment:archive/operations total=0.00044 eff=0.00078
deployment:probe/navigation total=0.00007 eff=0.02087
deployment:probe/research total=0.00014 eff=0.00233
deployment:scout-overprovisioned/science total=0.00008 eff=0.0385
deployment:scout/navigation total=0.00014 eff=0.02895
deployment:shuttle/navigation total=0.00002 eff=0.64927
```

The `probe` of `starfleet` and the `probe` of `outpost` stay apart because they have different teams. If both had the same team, `aggregate=controller` would merge them into one entry. Add the namespace to the aggregate when you want to be sure. The cost of `archive` now sits under `operations`, and `__unallocated__` is gone from the result.

You can now join groupings, find a workload without a team, repair its label and explain why an old window keeps its old attribution. The cost of the whole cluster is still bigger than the sum of the teams, because the nodes have capacity that no pod requests. The next part looks at that part of the bill.

## Common pitfalls

> [!WARNING]
> - **Expecting the new label in an old window.** A closed window keeps the attribution that the pods had when they ran. Ask for a window that starts after the new pod appears.
> - **Querying too early.** OpenCost needs about five minutes after a pod starts before it lists the pod under its team. An empty or unchanged answer means "wait", not "the label is wrong".
> - **Grouping by controller without the namespace.** `aggregate=controller` merges Deployments with the same name from different namespaces. Use `namespace,controller` when the names can repeat.
> - **Deleting the old pod by hand.** The Deployment controller already replaces the pod when you change the template. Change the Deployment, never the pod.
