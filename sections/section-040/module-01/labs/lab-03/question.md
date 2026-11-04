---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

## Scenario

The `starfleet` team needs a cost report based on new internal rates. OpenCost
1.121.3 and Prometheus already run in the cluster. The terminal has the
`kubectl-cost` v0.6.6 plugin. One scrape job, `probe-broken`, deliberately
receives an error from `probe`. Record that error without repairing the job.

## Tasks

1. **Change the pricing model.** In the namespace `opencost`, update the
   ConfigMap `custom-pricing-model`. Keep `provider: custom`. Set the string
   values `CPU: "0.045"`, `RAM: "0.006"`, `spotCPU: "0.009"` and
   `internetNetworkEgress: "0.09"`. Keep the other prices. Make OpenCost use
   these rates. Its `/allNodePricing` API must report the new regular CPU,
   memory and spot CPU rates. Its `/metrics` endpoint must expose
   `kubecost_network_internet_egress_cost` with value `0.09`.

2. **Save the plugin report.** Read the key `window` of the ConfigMap
   `default/cost-report-window`. Use `kubectl cost namespace` with
   `--opencost`, `--use-proxy`, `--historical`, that exact `--window`,
   `--idle=false` and `--show-efficiency=false`. Save its standard output to
   `/tmp/cnpe-cost-review/namespace-cost.txt`.

3. **Save a pod query.** Query Prometheus for
   `kube_pod_info{namespace="starfleet"}`. Save the complete successful
   instant-query JSON response to `/tmp/cnpe-cost-review/pods.json`. It must
   contain a nonempty vector with only `starfleet` pod information.

4. **Save the scrape error.** Find the active Prometheus target whose
   `job` label is `probe-broken`. Save only its nonempty `lastError` text to
   `/tmp/cnpe-cost-review/target-error.txt`. A final newline is allowed.
   Keep the target present and `down`.

Keep the workloads and the ConfigMap `cost-report-window` unchanged. All three
files belong on the terminal, outside the cluster. Costs use an internal price
list; they are not a cloud bill.
