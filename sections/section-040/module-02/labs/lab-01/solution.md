# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-040/module-02/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Read the window

The ConfigMap `report-window` holds the closed window the grader uses. Read its key `window`:

```bash
kubectl -n default get configmap report-window -o jsonpath='{.data.window}'
```

```text
1793584449,1793584659
```

The two numbers are Unix timestamps in seconds. The window fixes the start and end of the measurement. Late samples can still change its costs; compare the same window after collection settles. Your timestamps are different from the ones shown here.

## Step 2: Ask OpenCost for the cost of each team

Store the window in a shell variable, then call the allocation API through the Kubernetes API server. The parameter `aggregate=label:team` groups the answer by the value of the pod label `team`. The parameter `filter` keeps only the two namespaces of the task. The `%22` is the URL encoding of a quote character:

```bash
WINDOW=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=${WINDOW}&aggregate=label:team&filter=namespace:%22starfleet%22,%22outpost%22" | jq -r '.data[0] | to_entries[] | "\(.key) \(.value.totalCost)"'
```

```text
__unallocated__ 0.00047
navigation 0.00025
research 0.00015
```

The entry `__unallocated__` is the cost of the pods that have no `team` label. In the stored window that is the pod of `archive`. Your numbers are different from the ones shown here, because the cost depends on the time the cluster ran.

## Step 3: Store the report

Create the ConfigMap with the window and the three costs. Replace the numbers with the values from your own output:

```bash
kubectl -n default create configmap team-cost-report \
  --from-literal=window="$WINDOW" \
  --from-literal=navigation=0.00025 \
  --from-literal=research=0.00015 \
  --from-literal=unallocated=0.00047
```

```text
configmap/team-cost-report created
```

## Step 4: Label the pods of archive

OpenCost reads the labels of pods, not of Deployments. Save this as `deployment-patch-archive-team.yaml`:

```yaml
spec:
  template:
    metadata:
      labels:
        team: operations
```

Apply it. The Deployment controller starts a new pod with the label and stops the old one:

```bash
kubectl -n outpost patch deployment archive --patch-file deployment-patch-archive-team.yaml
kubectl -n outpost rollout status deployment/archive
```

Then check that the new pod carries the label:

```bash
kubectl -n outpost get pods -L team
```

The row of `archive` shows `operations` in the `TEAM` column. Do not delete the pod by hand. A pod keeps the labels it had when it was created, so only a new pod carries the new label.

## Step 5: Wait until OpenCost lists the new pod

OpenCost needs about five minutes after the pod starts. Ask for the cost of each pod and team since the patch. Repeat the command until the new pod of `archive` shows under `operations`:

```bash
kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=15m&aggregate=pod,label:team&filter=namespace:%22outpost%22" | jq -r '.data[0] | keys[]'
```

```text
archive-54fb6dc9df-w52r5/operations
archive-5ccc47f8db-884s2/__unallocated__
probe-6bb45869cf-rq2mw/research
```

The old pod stays under `__unallocated__`, because a closed window keeps the attribution that the pods had when they ran. Your pod names are different from the ones shown here, and the pod names in this listing are examples.

## Step 6: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-040/module-02/labs/lab-01
```

The grader checks the label on the pod template and on the live pod, asks OpenCost for the same window and compares your numbers with the answer. It accepts a value within 15 percent. It retries for up to 8 minutes, so a submit that comes too early does not fail at once.

```text
OK: the pod archive-54fb6dc9df-w52r5 carries team=operations
OK: OpenCost lists archive-54fb6dc9df-w52r5 under the team operations
OK: the report names the window 1793584449,1793584659
OK: navigation cost 0.00025 (OpenCost: 0.00025)
OK: research cost 0.00015 (OpenCost: 0.00015)
OK: unallocated cost 0.00047 (OpenCost: 0.00047)
OK: the other workloads are unchanged
PASS: archive is attributed to operations and the team costs match OpenCost
```

## Common mistakes

* Using `window=1h` for the report instead of the stored window. The window `1h` moves, so your numbers drift away from the grader's numbers.
* Putting the label only on the Deployment (`metadata.labels`). The pods do not get it, and OpenCost still lists `archive` under `__unallocated__`.
* Forgetting the `filter`. Then `__unallocated__` also holds the system namespaces, and the `unallocated` key is far too big.
* Deleting the pod by hand or changing requests. The grader rejects both.
