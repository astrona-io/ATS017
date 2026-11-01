# Scale Workloads With The HorizontalPodAutoscaler — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with the
astrona `metricsServer` addon (metrics-server v0.9.0, `--kubelet-insecure-tls`).
Namespace `starfleet` runs `scout` (podinfo 6.15.0, CPU request `100m`),
`scout-norequests` (no resources) and the `shuttle` client. No HPA exists yet.
Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-030-01
```

`astrona destroy` takes the environment name (`metadata.name` =
`ats-017-playground-030-01`), not the config path. `astrona submit` and
`astrona test` do not apply — there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, addon, preloaded images, starting manifests) |
| `manifests/lab-start.yaml` | Namespace, `scout`, `scout-norequests` and `shuttle` |
| `docs/overview.md` | What the environment contains and ideas to try |
