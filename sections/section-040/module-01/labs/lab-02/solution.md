---
estimated_duration: 25m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-040/module-01/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Read the window

The ConfigMap `report-window` holds the closed window the grader uses:

```bash
kubectl -n default get configmap report-window -o jsonpath='{.data.window}'
```

```text
1793572455,1793572815
```

Your timestamps are different from the ones shown here. The closed window fixes the measurement period. Late samples can still change its values until collection settles.

## Step 2: Ask OpenCost for each Deployment

Store the window in a shell variable, and query the allocation API with `aggregate=namespace,controller`. This keeps the `probe` of `starfleet` apart from the `probe` of `outpost`. The `jq` filter keeps the Deployments of `starfleet` and prints the cost and the efficiency figures:

```bash
WINDOW=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=${WINDOW}&aggregate=namespace,controller" | jq -r '.data[0] | to_entries[] | select(.key | startswith("starfleet/")) | "\(.key) cost=\(.value.totalCost) cpuEff=\(.value.cpuEfficiency) ramEff=\(.value.ramEfficiency) totalEff=\(.value.totalEfficiency)"'
```

```text
starfleet/deployment:crunch cost=0.00162 cpuEff=0.99967 ramEff=0.80127 totalEff=0.98721
starfleet/deployment:probe cost=0.00007 cpuEff=0.01386 ramEff=0.37903 totalEff=0.04848
starfleet/deployment:reports cost=0.00093 cpuEff=0.00002 ramEff=0.21153 totalEff=0.00577
starfleet/deployment:scout cost=0.00007 cpuEff=0.01515 ramEff=0.6829 totalEff=0.13078
starfleet/deployment:shuttle cost=0.00004 cpuEff=0.59384 ramEff=0.42139 totalEff=0.56397
```

The numbers in your output are a little different. The order is the same.

## Step 3: Sort by efficiency, not by cost

`crunch` costs the most, but its `totalEfficiency` is close to `1`: it uses what it requests. `reports` costs less, but its `cpuEfficiency` is `0.00002`. It requests `300m` CPU and uses almost none, so its `totalEfficiency` is the lowest. Sort the same data by `totalEfficiency` to confirm:

```bash
kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=${WINDOW}&aggregate=namespace,controller" | jq -r '[.data[0] | to_entries[] | select(.key | startswith("starfleet/"))] | sort_by(.value.totalEfficiency) | .[] | "\(.key) \(.value.totalEfficiency)"'
```

```text
starfleet/deployment:reports 0.00577
starfleet/deployment:probe 0.04848
starfleet/deployment:scout 0.13078
starfleet/deployment:shuttle 0.56397
starfleet/deployment:crunch 0.98721
```

The first line is the answer: `reports`.

## Step 4: Store the answer and submit

Create the ConfigMap with only the Deployment name. Use the name from your own output:

```bash
kubectl -n default create configmap least-efficient --from-literal=controller=reports
```

```text
configmap/least-efficient created
```

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-040/module-01/labs/lab-02
```

```text
OK: reports is a Deployment in starfleet (totalEfficiency 0.00577)
OK: reports has the lowest totalEfficiency
OK: the workloads are unchanged
PASS: reports is the least efficient Deployment in starfleet
```

## Common mistakes

* Sorting by `totalCost`. The answer `crunch` is rejected: it costs the most, but it uses what it requests.
* Using `aggregate=controller` without the namespace. The key then has no namespace, and Deployments with the same name in two namespaces can merge.
* Storing the full key `starfleet/deployment:reports`. Store only the name. The grader also accepts the full key, but the task asks for the name.
* Changing the requests of `reports` to make it efficient. The task asks you to find the workload, not to change it.
