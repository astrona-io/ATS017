---
estimated_duration: 25m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-040/module-01/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Read the window

The ConfigMap `report-window` holds the closed window the grader uses. Read its key `window`:

```bash
kubectl -n default get configmap report-window -o jsonpath='{.data.window}'
```

```text
1793570659,1793571019
```

The two numbers are Unix timestamps in seconds. The window fixes the start and end of the measurement. Late samples can still change its costs; compare the same window after collection settles. Your timestamps are different from the ones shown here.

## Step 2: Ask OpenCost for the cost of each namespace

Store the window in a shell variable, then call the allocation API through the Kubernetes API server. The parameter `aggregate=namespace` groups the answer by namespace. The `jq` filter prints the key and the `totalCost` of the two namespaces in the task:

```bash
WINDOW=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=${WINDOW}&aggregate=namespace" | jq -r '.data[0] | to_entries[] | select(.key == "starfleet" or .key == "outpost") | "\(.key) \(.value.totalCost)"'
```

```text
outpost 0.0018
starfleet 0.00052
```

The `outpost` namespace costs more than `starfleet`, although it runs one pod. The pod requests `500m` CPU and `512Mi` of memory, and it mounts the 20Gi volume, so OpenCost charges the CPU, the memory and the storage. Your numbers are different from the ones shown here, because the cost depends on the time the cluster ran.

## Step 3: Store the report

Create the ConfigMap with the window and the two costs. Replace the two numbers with the values from your own output:

```bash
kubectl -n default create configmap namespace-cost-report \
  --from-literal=window="$WINDOW" \
  --from-literal=starfleet=0.00052 \
  --from-literal=outpost=0.0018
```

```text
configmap/namespace-cost-report created
```

Print the ConfigMap to check the keys:

```bash
kubectl -n default get configmap namespace-cost-report -o jsonpath='{.data}'
```

```text
{"outpost":"0.0018","starfleet":"0.00052","window":"1793570659,1793571019"}
```

## Step 4: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-040/module-01/labs/lab-01
```

The grader asks OpenCost for the same window and compares your numbers with the answer. It accepts a value within 15 percent.

```text
OK: the report names the window 1793570659,1793571019
OK: starfleet total cost 0.00052 (OpenCost: 0.00052)
OK: outpost total cost 0.0018 (OpenCost: 0.0018)
OK: the workloads are unchanged
PASS: the namespace costs match OpenCost
```

## Common mistakes

* Using `window=1h` instead of the stored window. The window `1h` moves, so your numbers drift away from the grader's numbers.
* Adding a dollar sign or text to a cost key. The key holds only the number.
* Reading `cpuCost` instead of `totalCost`. The total includes memory, storage and network.
* Changing the requests of the workloads to make the numbers smaller. The grader checks that the workloads are unchanged.
