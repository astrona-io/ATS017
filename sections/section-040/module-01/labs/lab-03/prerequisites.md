# Prerequisites

You can edit and apply a ConfigMap, read JavaScript Object Notation (JSON)
with `jq`, and use `kubectl get --raw` to query a Service through the Kubernetes
Application Programming Interface (API) server. You know that OpenCost needs
prices and Prometheus metrics to calculate cost.

The terminal needs `kubectl`, Helm 4.3.0, `curl`, `jq` and `tar`. Bootstrap
checks these tools and installs `kubectl-cost` v0.6.6 beside `kubectl` on
`PATH`. Use a macOS terminal on arm64 or amd64, or a Linux terminal on amd64;
this plugin release has no Linux arm64 binary. Installing beside `kubectl`
can require `sudo` if that directory is not writable.

Bootstrap installs Prometheus chart 29.40.3 (Prometheus v3.15.1) and OpenCost
chart 2.5.33 (OpenCost 1.121.3). It creates `starfleet/scout`,
`starfleet/probe` and `outpost/scout`. The `probe-broken` job scrapes
`probe` at `/status/503`, which returns an HTTP error. Bootstrap waits for
allocation data, pod information and the failing scrape before finishing.
Allow about 12 to 20 minutes for preparation, separate from the task time.
