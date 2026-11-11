# Summary

OpenCost charges each container for the larger of what it requests and what it uses, so a request that is too high costs money even when the container is idle. This module followed that sentence from the inputs of a cost to the workload that wastes the most.

## What you learned

A cost allocation has three inputs for every container: a price, a request and a usage figure. The kubelet cAdvisor endpoint provides the usage, kube-state-metrics provides the requests, and OpenCost provides the node prices as metrics. Prometheus stores all three. OpenCost works in steps of one minute. For each minute it takes the larger of the request and the usage, adds the minutes of the window, and multiplies the result by the price of a core hour or a gibibyte hour. Storage is charged for the size of the bound volume, so a PersistentVolumeClaim costs money even when no data is written.

OpenCost needs two things to return non-zero numbers: a Prometheus that it can reach, and a price list. The chart sets the Prometheus address in the variable `PROMETHEUS_SERVER_ENDPOINT`, and it creates the price list in the ConfigMap `custom-pricing-model` when `opencost.customPricing.enabled` is true. Without the price list OpenCost logs `No pricing found for key=default` and every cost is zero. The Prometheus targets page shows whether the cAdvisor, kube-state-metrics and OpenCost jobs are `up`. The first costs appear about six minutes after a new start, and the numbers settle after about fifteen.

The allocation API answers at `/allocation/compute` on port `9003` of the Service `opencost`. The parameter `window` sets the period, as a duration such as `1h` or as a pair of Unix timestamps. A duration moves with the clock, while a closed pair of timestamps fixes the measurement period. Late samples can still change its values until collection settles. The parameter `aggregate` sets the grouping: `namespace`, `controller`, `pod` or `label:<name>`. The parameter `filter` keeps only the matching items, and `includeIdle=true` adds the cost of node capacity that no pod requests as an entry named `__idle__`. Each entry has `cpuCost`, `ramCost`, `pvCost`, `networkCost` and `totalCost`, and the totals of the namespaces add up to the cost of the allocated capacity.

Efficiency compares usage with the request. `cpuEfficiency` is the CPU usage divided by the CPU request, `ramEfficiency` is the same for memory, and `totalEfficiency` is the mean of the two weighted by cost. A value near zero means the container reserves much more than it uses. A value above one means the container uses more than it requests, so OpenCost charges the usage and the container is at risk of throttling or eviction. The workload that costs the most is not always the one that wastes the most, so right-sizing starts from a list sorted by efficiency and not by cost. The key facts to remember are these:

- Cost is the larger of request and usage, multiplied by the price.
- No price list means a cost of zero, with no error.
- A closed window of timestamps gives repeatable numbers.
- `aggregate=namespace,controller` keeps controllers of different namespaces apart.
- Costs on `kind` come from a price list and are not a bill.

The custom pricing model sets internal rates, including spot CPU and Internet
egress. OpenCost's active node prices and network metric confirm that the
model reached the running service. The `kubectl cost` plugin reads allocation
from OpenCost; `--opencost` selects its endpoint and `--historical` reports
the cost inside the selected window. New rates do not rewrite old samples.

Prometheus pod information and scrape status answer different questions.
A namespace selector limits `kube_pod_info` to the team's pods. The targets
API identifies failed scrapes through `health` and `lastError`. Saving the
complete query response or the exact error preserves evidence for review.

<!-- astrona:playground:destroy -->
