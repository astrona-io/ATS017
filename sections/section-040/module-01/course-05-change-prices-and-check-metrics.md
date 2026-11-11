# Change Prices And Check Metrics

The `starfleet` cost report needs new internal rates, but changing a price
file is only half the job. OpenCost must load those rates, and Prometheus
must still supply the data behind the report. A useful check follows the
price into OpenCost, reads a cost table, then inspects the metrics and scrape
errors that can explain a missing result.

## Change the custom pricing model

A ConfigMap stores named strings in the Kubernetes Application Programming
Interface (API). OpenCost 1.121.3 watches the ConfigMap
`opencost/custom-pricing-model` for custom prices. The installed chart has
custom pricing enabled and uses the `custom` provider, which applies internal
rates on this cluster without cloud billing.

<!-- astrona:playground:renew -->

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

Apply it:

```sh
kubectl apply -f configmap-custom-pricing-model.yaml
```

`CPU` prices one core-hour, and `RAM` prices one gibibyte-hour.
`spotCPU` prices a core-hour for a node classified as spot capacity, which is
interruptible capacity. Changing that rate does not turn a regular node into
a spot node. `internetNetworkEgress` prices each gigabyte of traffic sent to
the Internet. These are rates in United States dollars (USD), not totals.
The quoted values are strings because ConfigMap `data` requires strings.

Then check the result. Restart the OpenCost Deployment, which replaces its
pods, so it rebuilds its cached node prices as well as reading the new model:

```sh
kubectl -n opencost rollout restart deployment/opencost
kubectl -n opencost rollout status deployment/opencost --timeout=180s
kubectl get --raw /api/v1/namespaces/opencost/services/opencost:9003/proxy/allNodePricing | jq '.data'
kubectl get --raw /api/v1/namespaces/opencost/services/opencost:9003/proxy/metrics | grep '^kubecost_network_internet_egress_cost '
```

In the API response, look for `CPU` equal to `0.045` and `RAM` equal to
`0.006` under `default`, and `CPU` equal to `0.009` under `default,spot`.
The metric should report the Internet egress rate `0.09`. Repeat the reads
while OpenCost finishes loading. The network metric proves that OpenCost
uses the rate; it does not prove that this cluster measured Internet traffic.

## Read a cost table with kubectl cost

A kubectl plugin is an executable that adds a command to `kubectl`.
The playground installs `kubectl-cost` v0.6.6 on the terminal. Confirm its
version and inspect the namespace command's flags before using it:

```sh
kubectl cost version
kubectl cost namespace --help
kubectl cost namespace --opencost --use-proxy --historical --window 10m --idle=false --show-efficiency=false
```

Look for v0.6.6 in the version information and `--opencost` in the help.
The flag selects namespace `opencost`, Service `opencost`, port `9003` and
allocation path `/allocation/compute`. `--use-proxy` sends the request
through the Kubernetes API server instead of opening a port-forward.

Read the namespace rows and their total costs. `--historical` reports cost
inside the selected window. Without it, this plugin projects a monthly rate
from the same samples. `--idle=false` excludes the idle row, while
`--show-efficiency=false` hides efficiency columns. These flags control the
query and its display; the plugin still reads the OpenCost allocation API.

A rolling `10m` window can contain samples from before and after a rate
change. Historical samples keep their recorded prices. To compare saved
reports, use a closed window with the same start and end timestamps.

## Save pod information from Prometheus

Prometheus stores time series, which are labelled samples collected over
time. Prometheus Query Language (PromQL) selects and calculates these series.
The metric `kube_pod_info` carries pod metadata from kube-state-metrics,
which reads Kubernetes objects and exposes them as metrics. Start with a
namespace filter so the response contains only the team's pods:

```sh
mkdir -p /tmp/cnpe-cost-review
kubectl get --raw '/api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1/query?query=kube_pod_info%7Bnamespace%3D%22starfleet%22%7D' > /tmp/cnpe-cost-review/pods.json
jq '.status, .data.resultType, .data.result' /tmp/cnpe-cost-review/pods.json
```

The encoded query is `kube_pod_info{namespace="starfleet"}`. Look for a
successful response, `resultType` set to `vector`, and results whose
`namespace` label is `starfleet`. An instant query evaluates a selector at
one time; each returned series includes labels and a timestamped value.
Saving the full JavaScript Object Notation (JSON) response preserves both.
This metric describes pods; it does not report their resource usage or cost.

## Find a scrape error

A scrape is Prometheus fetching metrics from an endpoint. A target is an
endpoint that Prometheus is configured to scrape. The playground includes
`probe-broken`, a job that requests `/status/503` from `probe` and receives an
HTTP error. It is separate from the targets that supply OpenCost's usage,
request and price data.

```sh
kubectl get --raw /api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1/targets | jq '.data.activeTargets[] | select(.health == "down") | {job: .labels.job, scrapeUrl, lastError}'
kubectl get --raw /api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job == "probe-broken") | .lastError' > /tmp/cnpe-cost-review/target-error.txt
cat /tmp/cnpe-cost-review/target-error.txt
```

Look for the `probe-broken` job and its actual error. `health` describes the
latest scrape result. `lastError` explains the failure, while `scrapeUrl`
identifies the endpoint to investigate. The `-r` flag makes `jq` save plain
text without JSON quotation marks. Keep the failing job in place for this
exercise.

You can now change the internal rates and follow them into OpenCost's API,
then read the resulting allocation through the plugin. You can also save a
filtered Prometheus response and isolate a failing scrape. When a report has
a gap, these checks help establish which input needs attention before you
change workload requests.

## Common pitfalls

> [!WARNING]
> - **Checking only the ConfigMap.** Read OpenCost's active node prices and
>   network rate after the reload.
> - **Treating spot pricing as node selection.** `spotCPU` sets a rate; it
>   does not change the node's capacity type.
> - **Comparing a monthly projection with a window total.** Use
>   `--historical` for cost inside the chosen window.
> - **Saving a successful but empty query.** Check the response status and
>   the result array, including the namespace labels.
> - **Guessing a scrape error.** Read and save the target's live `lastError`.
