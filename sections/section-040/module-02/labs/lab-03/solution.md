# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-040/module-02/labs/lab-03
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Rank the Deployments by cost

The ConfigMap `report-window` holds the closed window of the task. Ask OpenCost for the cost of each Deployment in the namespace `starfleet`, with the cheapest first. The parameter `aggregate=namespace,controller` groups the answer by namespace and Deployment, and the parameter `filter=namespace:"starfleet"` keeps only that namespace:

```bash
WINDOW=$(kubectl -n default get configmap report-window -o jsonpath='{.data.window}')
kubectl get --raw "/api/v1/namespaces/opencost/services/opencost:9003/proxy/allocation/compute?window=${WINDOW}&aggregate=namespace,controller&filter=namespace:%22starfleet%22" | jq -r '[.data[0] | to_entries[]] | sort_by(.value.totalCost) | .[] | "\(.key) total=\(.value.totalCost) cpu=\(.value.cpuCost) ram=\(.value.ramCost)"'
```

The keys have the form `starfleet/deployment:<name>`. The last line is `relay`: it runs three replicas that each request `400m` CPU and `256Mi` of memory, so it is the most expensive Deployment by far. The first line is `beacon`: one replica with `25m` and `32Mi`. Your numbers are different, because the cost depends on the time the cluster ran, but the order is the same.

Confirm the cause with the replica counts and the requests:

```bash
kubectl -n starfleet get deploy -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,CPU:.spec.template.spec.containers[0].resources.requests.cpu,MEMORY:.spec.template.spec.containers[0].resources.requests.memory'
```

```text
NAME      REPLICAS   CPU    MEMORY
beacon    1          25m    32Mi
relay     3          400m   256Mi
scout     1          100m   64Mi
shuttle   1          50m    48Mi
```

OpenCost charges a pod for what it requests, or for what it uses when that is more. Three replicas with a large request cost three times the large request. That is why `relay` is at the top.

## Step 2: Write the report

Create the ConfigMap with the window and the two names:

```bash
kubectl -n default create configmap cost-scaling-report \
  --from-literal=window="${WINDOW}" \
  --from-literal=highest=relay \
  --from-literal=lowest=beacon
```

```text
configmap/cost-scaling-report created
```

## Step 3: Scale by cost

Scale the most expensive Deployment down to one replica and the least expensive up to three. The command `kubectl scale` changes only `spec.replicas`, so the requests stay as they are:

```bash
kubectl -n starfleet scale deploy/relay --replicas=1
kubectl -n starfleet scale deploy/beacon --replicas=3
kubectl -n starfleet rollout status deploy/relay
kubectl -n starfleet rollout status deploy/beacon
```

```text
deployment.apps/relay scaled
deployment.apps/beacon scaled
deployment "relay" successfully rolled out
deployment "beacon" successfully rolled out
```

Check that the pods run and both Services answer:

```bash
kubectl -n starfleet get pods -l 'app in (relay, beacon)'
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://relay
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://beacon
```

One `relay` pod and three `beacon` pods are `Running`, and both `curl` commands print `200`.

## Step 4: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-040/module-02/labs/lab-03
```

The grader reads the ConfigMap and the Deployments, and sends a request from `shuttle` to both Services. It does not call OpenCost, because a change in replicas shows up in OpenCost only after several minutes.

```text
OK: the report uses the window 1762500000,1762500210
OK: relay is the most expensive and beacon the least expensive Deployment
PASS: cost-scaling-report names the right Deployments
OK: relay runs 1 replica and beacon runs 3, all ready
OK: the requests are unchanged and shuttle gets 200 from relay and beacon
OK: scout and shuttle still run one replica each
PASS: the replica counts follow the cost ranking
```

## Common mistakes

* Ranking by `totalEfficiency` instead of `totalCost`. Efficiency says how much of a request is used. The task asks for the money, so sort by `totalCost`.
* Reading the cost of one pod instead of the Deployment. The controller entry sums all replicas. Use `aggregate=namespace,controller`.
* Lowering the requests of `relay` instead of its replica count. The task asks for one replica with the same request. The grader fails when a request changed.
* Scaling `beacon` to three replicas by changing the requests. More replicas means more pods, not a bigger pod.
* Expecting OpenCost to show the new costs at once. OpenCost reads Prometheus, which scrapes every minute, so the change appears only after several minutes. The grader checks the Deployments, not OpenCost.
