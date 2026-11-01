# Read Cost Allocation With OpenCost — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-040-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with the
astrona `metricsServer` addon, a small Prometheus (Helm chart
`prometheus-community/prometheus` 29.40.3, Prometheus v3.15.1, with
kube-state-metrics) and OpenCost (Helm chart `opencost/opencost` 2.5.33,
OpenCost 1.121.3) with the on-premises default prices. Namespace `starfleet`
runs `scout`, `probe`, `scout-busy` and `shuttle`. Namespace `outpost` runs
`probe` with a 20Gi PersistentVolumeClaim. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-040-01
```

`astrona destroy` takes the environment name (`metadata.name` =
`ats-017-playground-040-01`), not the config path. `astrona submit` and
`astrona test` do not apply — there is no grading. The bootstrap script needs
`helm` on the machine that runs `astrona run`. OpenCost needs about ten
minutes of samples before the allocation API returns usable numbers.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, addon, preloaded images, bootstrap script) |
| `bootstrap/prepare.sh` | Applies the workloads, then installs Prometheus and OpenCost with Helm (chart versions pinned in the script) |
| `bootstrap/prometheus-values.yaml` | Helm values for the small Prometheus, including the scrape job for OpenCost |
| `bootstrap/opencost-values.yaml` | Helm values for OpenCost, including the default on-premises price list |
| `manifests/lab-start.yaml` | Namespaces, the workloads and the PersistentVolumeClaim |
| `docs/overview.md` | What the environment contains and ideas to try |
