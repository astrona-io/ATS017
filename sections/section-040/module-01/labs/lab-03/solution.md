# Solution Walkthrough

Update the prices, check what OpenCost serves, then save the cost and
monitoring evidence on the terminal. A ConfigMap stores named strings in the
Kubernetes Application Programming Interface (API).

| Goal | Source | Evidence |
| --- | --- | --- |
| Change the rates | `opencost/custom-pricing-model` | Four new string values |
| Confirm active prices | OpenCost API | Regular, spot and Internet egress rates |
| Read namespace costs | `kubectl cost namespace` | Table for the stored window |
| Read pod information | Prometheus instant query | Full JSON response |
| Find a scrape failure | Prometheus targets API | The target's `lastError` |

## The feedback loop

Run grading from the host terminal where you launched the lab:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-01/labs/lab-03
```

The five checks are `pricing-model`, `pricing-active`, `cost-report`,
`pod-query` and `scrape-error`. Before any changes, the old prices and the
missing files should cause all five to fail. Run grading after each step.

## Step 1: Inspect the starting state

Read the existing prices and the plugin version:

```sh
kubectl -n opencost get configmap custom-pricing-model -o json | jq '.data'
kubectl cost version
kubectl cost namespace --help
```

Look for the original `CPU`, `RAM`, `spotCPU` and `internetNetworkEgress`
values. The plugin's version information should identify v0.6.6, and its
namespace help should list `--opencost`. This step changes no check.

## Step 2: Apply and reload the rates

Save this as `configmap-custom-pricing-model.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-pricing-model
  namespace: opencost
data:
  provider: custom
  description: Starfleet internal rates
  CPU: "0.045"
  RAM: "0.006"
  spotCPU: "0.009"
  spotRAM: "0.000892"
  GPU: "0.95"
  storage: "0.00005479452"
  zoneNetworkEgress: "0.01"
  regionNetworkEgress: "0.01"
  internetNetworkEgress: "0.09"
```

`metadata` identifies the existing object. `data` holds strings, so quote the
prices. `CPU` and `RAM` price a core-hour and a gibibyte-hour; `spotCPU` prices
a spot core-hour. `internetNetworkEgress` prices a gigabyte sent to the
Internet. The remaining entries preserve the existing prices.

Apply it:

```sh
kubectl apply -f configmap-custom-pricing-model.yaml
```

Then check the result:

```sh
kubectl -n opencost rollout restart deployment/opencost
kubectl -n opencost rollout status deployment/opencost --timeout=180s
kubectl get --raw /api/v1/namespaces/opencost/services/opencost:9003/proxy/allNodePricing | jq '.data'
kubectl get --raw /api/v1/namespaces/opencost/services/opencost:9003/proxy/metrics | grep '^kubecost_network_internet_egress_cost '
```

OpenCost watches the ConfigMap. Restarting its Deployment also rebuilds its
cached node prices. Look for `default.CPU` equal to `0.045`, `default.RAM`
equal to `0.006`, and `CPU` equal to `0.009` under `default,spot`. The network
metric should have value `0.09`; repeat the checks while OpenCost reloads.
This confirms a rate, not measured Internet traffic or a network bill.

**Run the check.** `pricing-model` and `pricing-active` should now pass.

## Step 3: Save the cost table

Read the window, then create the result directory:

```sh
kubectl -n default get configmap cost-report-window -o jsonpath='{.data.window}'
mkdir -p /tmp/cnpe-cost-review
```

Replace `<WINDOW>` below with the complete comma-separated value you just
read. Keep the quotes around it:

```sh
kubectl cost namespace --opencost --use-proxy --historical --window '<WINDOW>' --idle=false --show-efficiency=false > /tmp/cnpe-cost-review/namespace-cost.txt
cat /tmp/cnpe-cost-review/namespace-cost.txt
```

`--opencost` selects the OpenCost Service and API path. `--use-proxy` sends the
query through the Kubernetes API server. `--historical` reports the cost
inside the window rather than a projected monthly rate. The final two flags
exclude the idle row and hide efficiency columns. Look for rows for
`starfleet` and `outpost`, and the total cost column.

The stored window is in the past. Its cost uses the price samples from that
period; changing today's price does not rewrite old Prometheus samples.

**Run the check.** `cost-report` should now pass.

## Step 4: Save the pod query

Prometheus Query Language (PromQL) selects time series by metric name and
labels. `kube_pod_info` contains pod metadata from kube-state-metrics, which
turns Kubernetes object information into metrics. This selector limits the
query to `starfleet`:

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1/query?query=kube_pod_info%7Bnamespace%3D%22starfleet%22%7D' > /tmp/cnpe-cost-review/pods.json
jq '.status, .data.result' /tmp/cnpe-cost-review/pods.json
```

The URL encodes `kube_pod_info{namespace="starfleet"}`. Look for `success`, a
nonempty result and only the namespace `starfleet`. Save the full JavaScript
Object Notation (JSON) response, including the evaluation timestamps. The
grader repeats the query at that time and compares the series and values.

**Run the check.** `pod-query` should now pass.

## Step 5: Save the failing target's error

A scrape is Prometheus fetching metrics from an endpoint. The targets API
reports each active target's `health` and the most recent scrape error in
`lastError`. Inspect the failing targets, then save only the selected error:

```sh
kubectl get --raw /api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1/targets | jq '.data.activeTargets[] | select(.health == "down") | {job: .labels.job, scrapeUrl, lastError}'
kubectl get --raw /api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job == "probe-broken") | .lastError' > /tmp/cnpe-cost-review/target-error.txt
cat /tmp/cnpe-cost-review/target-error.txt
```

Look for the `probe-broken` job and an HTTP scrape error. `jq -r` writes the
text without JSON quotation marks. Leave the failing job in place.

**Run the check.** `scrape-error` should now pass. Submit the completed task:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-01/labs/lab-03
```

## If a check stays red

- **`pricing-model`:** Check the namespace, field spelling and quoted values.
- **`pricing-active`:** Wait for the rollout and metric collection, then read
  the endpoints again. Editing the ConfigMap alone does not prove that the
  cached node rates have changed.
- **`cost-report`:** Use the exact stored window and all the requested flags.
  Save standard output, which holds the table; version information uses
  standard error. Recreate the file if you saved a projected monthly rate.
- **`pod-query`:** Keep the full JSON response. A list of pod names or an
  empty successful response is not the requested evidence.
- **`scrape-error`:** Save only `lastError` with `jq -r`. Select the job name,
  and leave its deliberate failing endpoint unchanged.
