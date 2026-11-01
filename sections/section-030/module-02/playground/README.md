# Right-Size Workloads From Measured Usage — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-030-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with the
astrona `metricsServer` addon (metrics-server v0.9.0, `--kubelet-insecure-tls`)
and a small Prometheus (Helm chart `prometheus-community/prometheus` 29.40.3,
Prometheus v3.15.1) that scrapes the kubelet's cAdvisor metrics. Namespace
`starfleet` runs `scout-overprovisioned`, `scout-underprovisioned` and the
`shuttle` client, which sends one request to each scout every second. No HPA
exists. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-030-02
```

`astrona destroy` takes the environment name (`metadata.name` =
`ats-017-playground-030-02`), not the config path. `astrona submit` and
`astrona test` do not apply — there is no grading. The bootstrap script needs
`helm` on the machine that runs `astrona run`.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, addon, preloaded images, bootstrap script) |
| `bootstrap/prepare.sh` | Applies the workloads and installs Prometheus with Helm (chart version pinned in the script) |
| `manifests/lab-start.yaml` | Namespace, the two scouts, their Services and `shuttle` |
| `docs/overview.md` | What the environment contains and ideas to try |
