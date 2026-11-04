# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-040/module-02/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Compare efficiency with usage

The ConfigMap `report-window` holds the closed window of the task. Ask OpenCost for the cost and the efficiency of each Deployment in the namespace `starfleet`, with the lowest efficiency first. The parameter `aggregate=namespace,controller` groups the answer by namespace and Deployment:

```bash
WINDOW=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=${WINDOW}&aggregate=namespace,controller&filter=namespace:%22starfleet%22" | jq -r '[.data[0] | to_entries[]] | sort_by(.value.totalEfficiency) | .[] | "\(.key) eff=\(.value.totalEfficiency) total=\(.value.totalCost)"'
```

The Deployment with the lowest `totalEfficiency` is `scout-overprovisioned`. It also has the highest `totalCost`, so it wastes the most money. The Deployment `crunch` has a high efficiency, because it uses what it requests. Your numbers are different, because the cost depends on the time the cluster ran.

Compare the request with the real usage:

```bash
kubectl -n starfleet get deployment scout-overprovisioned -o json | jq -c '.spec.template.spec.containers[0].resources'
kubectl -n starfleet top pods
```

The pod of `scout-overprovisioned` requests `1500m` CPU and `1Gi` of memory and uses about `2m` and `25Mi`. Metrics-server needs about a minute after the pod starts before `kubectl top` shows values.

## Step 2: Lower the requests

The command `kubectl set resources` edits the pod template, so the Deployment controller starts a new pod with the new requests. Request `50m` CPU and `64Mi` memory: the usage plus a margin:

```bash
kubectl -n starfleet set resources deployment/scout-overprovisioned --requests=cpu=50m,memory=64Mi
kubectl -n starfleet rollout status deployment/scout-overprovisioned
```

```text
deployment.apps/scout-overprovisioned resource requirements updated
deployment "scout-overprovisioned" successfully rolled out
```

Check that the new pod runs and answers:

```bash
kubectl -n starfleet get pods -l app=scout-overprovisioned
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://scout-overprovisioned
```

The pod is `Running`, and the second command prints `200`.

## Step 3: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-040/module-02/labs/lab-02
```

The grader reads the requests of the Deployment and of the running pod, and sends a request from `shuttle` to the Service. It does not call OpenCost, because OpenCost shows the change only after several minutes.

```text
OK: the Deployment requests 50m CPU and 64Mi memory
OK: the pod is Running with fitting requests and shuttle gets 200
OK: the other workloads are unchanged
PASS: scout-overprovisioned requests fit its usage
```

## Common mistakes

* Lowering `crunch`. It has a high efficiency, because it uses what it requests. Lowering it only hurts it.
* Requesting less than the usage. A memory request and limit below `25Mi` can get the container killed. Keep a margin.
* Editing the pod instead of the Deployment. The next restart brings the old request back. Change the Deployment.
* Expecting a lower bill on one node. The cost of the workload moves to idle cost. The bill falls only when you remove capacity.
