# Solution

## Step 1: Ask OpenCost for the cost of each Deployment

The ConfigMap `report-window` holds the closed window of the task. The labels did not exist in that window, so group by namespace and controller, not by the label. The `%22` is the URL encoding of a quote character:

```bash
WINDOW=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=${WINDOW}&aggregate=namespace,controller&filter=namespace:%22starfleet%22,%22outpost%22" | jq -r '[.data[0] | to_entries[]] | sort_by(.value.totalEfficiency) | .[] | "\(.key) eff=\(.value.totalEfficiency) total=\(.value.totalCost)"'
```

The list is sorted by `totalEfficiency`, the lowest first. The first Deployment in the list is `starfleet/deployment:analytics`. It requests `1200m` CPU and `1Gi` of memory and uses almost nothing. Your numbers are different, because the cost depends on the time the cluster ran.

## Step 2: Store the report

Add the costs of the Deployments that each team owns: `scout` and `shuttle` for `navigation`, `probe` and `archive` for `operations`, and `analytics` for `science`. This command does the sums and writes the ConfigMap:

```bash
cost_of() {
  kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=${WINDOW}&aggregate=namespace,controller&filter=namespace:%22starfleet%22,%22outpost%22" | jq -r --arg key "$1" '.data[0][$key].totalCost'
}
add() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.8f", a + b }'; }
kubectl -n default create configmap cost-report \
  --from-literal=window="$WINDOW" \
  --from-literal=navigation="$(add "$(cost_of starfleet/deployment:scout)" "$(cost_of starfleet/deployment:shuttle)")" \
  --from-literal=operations="$(add "$(cost_of starfleet/deployment:probe)" "$(cost_of outpost/deployment:archive)")" \
  --from-literal=science="$(cost_of starfleet/deployment:analytics)" \
  --from-literal=least-efficient=analytics
```

```text
configmap/cost-report created
```

## Step 3: Label the pods

Three Deployments have no `team` label: `probe`, `analytics` and `archive`. OpenCost reads the labels of pods, so the label goes into the pod template. Save this as `deployment-patch-team-operations.yaml`:

```yaml
spec:
  template:
    metadata:
      labels:
        team: operations
```

Save this as `deployment-patch-team-science.yaml`:

```yaml
spec:
  template:
    metadata:
      labels:
        team: science
```

Apply the patches. Each patch makes the Deployment controller start a new pod:

```bash
kubectl -n starfleet patch deployment probe --patch-file deployment-patch-team-operations.yaml
kubectl -n outpost patch deployment archive --patch-file deployment-patch-team-operations.yaml
kubectl -n starfleet patch deployment analytics --patch-file deployment-patch-team-science.yaml
```

## Step 4: Right-size the least efficient Deployment

Request the usage plus a margin for `analytics`, and wait for the rollout of all three Deployments:

```bash
kubectl -n starfleet set resources deployment/analytics --requests=cpu=50m,memory=64Mi
kubectl -n starfleet rollout status deployment/analytics
kubectl -n starfleet rollout status deployment/probe
kubectl -n outpost rollout status deployment/archive
```

Then check the labels and the answer of the Service:

```bash
kubectl get pods -A -L team | grep -E "starfleet|outpost"
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://analytics
```

Every pod shows its team, and the second command prints `200`.

## Step 5: Submit

```bash
astrona submit -c sections/section-040/capstone/labs/lab-01
```

The grader checks the labels on the pod templates, compares the numbers in `cost-report` with the answer of OpenCost for the stored window, checks the requests of `analytics`, checks that the other requests are unchanged, and sends a request from `shuttle` to `analytics`.

## Common mistakes

* Grouping the stored window by `label:team`. The labels did not exist then, so almost all of the cost sits in `__unallocated__`.
* Ranking by cost instead of efficiency. The least efficient Deployment is the one with the lowest `totalEfficiency`.
* Putting the label on `metadata.labels` of the Deployment. Only `spec.template.metadata.labels` reaches the pods.
* Changing the requests of `scout`, `probe` or `archive`. Only the least efficient Deployment changes.
