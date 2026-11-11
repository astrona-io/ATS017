# Rank Deployment Cost Before Changing Replicas

Changing a replica count changes future allocation. Record the measurement first, then change the workload. This keeps the decision tied to the data that justified it and lets another person check the same window.

Cost alone does not establish how many replicas a service needs. The exercise uses a fixed scaling request to practise reading allocation and changing replicas. In a platform, check demand, availability requirements and any autoscaler before reducing capacity.

## Keep one closed window

A closed window has a fixed start and end. Allow time for metrics to arrive before choosing its end. Late samples can still change historical results; save the response as evidence as well as the timestamps.

<!-- astrona:playground:renew -->

```sh
END=$(( $(date -u +%s) - 180 )); START=$((END - 300))
WINDOW="${START},${END}"
kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=${WINDOW}&aggregate=namespace,controller&filter=namespace:%22starfleet%22" > allocation-before.json
jq -e '.code == 200 and (.data[0] | type == "object")' allocation-before.json
```

After renewing the playground, allow about eight to ten minutes for a five-minute window and the three-minute sample delay. Recompute `END`, `START` and `WINDOW` when retrying. This collection time is separate from the exercise. The response must contain data. An empty result, a missing cost or a failed request is not a zero-cost workload. Wait for samples and repeat the query before proceeding.

## Select Deployments and compare costs

The allocation keys include the namespace and controller kind. Exclude other controllers and unallocated entries, then rank by `totalCost`:

```sh
jq '[.data[0] | to_entries[] | select(.key | startswith("starfleet/deployment:")) | {deployment: (.key | split(":")[1]), cost: .value.totalCost}] | sort_by(.cost)' allocation-before.json > ranked-costs.json
jq -e 'length >= 2 and all(.[]; (.cost | type == "number") and .cost >= 0)' ranked-costs.json
cat ranked-costs.json
```

Read the first and last entries as the least and most expensive Deployments for this window. If costs tie, the measurement does not identify a unique winner. Use another settled window or agree a tie-breaking rule before changing replicas. A high total cost can come from more replicas, larger requests or greater usage; it does not by itself mean waste.

## Record the decision and change only replicas

Save the chosen names in shell variables and record them with the window. This example changes only the highest-cost Deployment, after checking which workload it is:

```sh
LOWEST=$(jq -r 'first.deployment' ranked-costs.json)
HIGHEST=$(jq -r 'last.deployment' ranked-costs.json)
kubectl -n starfleet get deployment "$HIGHEST" -o yaml
kubectl -n starfleet get hpa
kubectl -n starfleet create configmap allocation-decision --from-literal=window="$WINDOW" --from-literal=highest="$HIGHEST" --from-literal=lowest="$LOWEST" --dry-run=client -o yaml | kubectl apply -f -
```

Check that the selected Deployment has no HPA controlling its replicas. Read its current replica count and save it before scaling:

```sh
ORIGINAL_REPLICAS=$(kubectl -n starfleet get deployment "$HIGHEST" -o jsonpath='{.spec.replicas}')
kubectl -n starfleet scale deployment "$HIGHEST" --replicas=1
kubectl -n starfleet rollout status deployment "$HIGHEST" --timeout=120s
kubectl -n starfleet get deployment "$HIGHEST" -o jsonpath='{.spec.replicas}{" desired; "}{.status.availableReplicas}{" available\n"}'
```

Scaling changes `spec.replicas`, leaving the pod template and its requests intact. Check the application's Service as well as availability before accepting the change. Restore the playground's count when finished:

```sh
kubectl -n starfleet scale deployment "$HIGHEST" --replicas="$ORIGINAL_REPLICAS"
kubectl -n starfleet rollout status deployment "$HIGHEST" --timeout=120s
```

A later cost comparison needs a new window entirely after the change and enough time for samples to arrive. Reusing the earlier window proves the original ranking; it cannot prove a saving from the new replica count. On this fixed kind node, lower workload allocation leaves more idle capacity and does not reduce a cloud bill.

## Common pitfalls

> [!WARNING]
> - **Ranking every allocation entry.** Select Deployments in the requested namespace before sorting.
> - **Treating missing data as cheap capacity.** Require numeric costs and enough settled samples.
> - **Scaling before recording evidence.** Preserve the window, response and chosen names first.
> - **Changing requests as well as replicas.** That changes two inputs and makes the effect harder to attribute.
