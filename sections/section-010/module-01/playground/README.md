# Set Requests, Limits And QoS Classes — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with the
astrona `metricsServer` addon (metrics-server v0.9.0, `--kubelet-insecure-tls`).
Namespace `starfleet` runs `scout` (podinfo 6.15.0) in three resource
variants, one per QoS class, and the `shuttle` client. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-010-01
```

`astrona destroy` takes the environment name (`metadata.name` =
`ats-017-playground-010-01`), not the config path. `astrona submit` and
`astrona test` do not apply — there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, addon, preloaded images, starting manifests) |
| `manifests/lab-start.yaml` | Namespace, the three `scout` variants and `shuttle` |
| `docs/overview.md` | What the environment contains and ideas to try |
