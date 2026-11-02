# Bound Tenants With ResourceQuota And LimitRange — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-050-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with two
tenant namespaces, `starfleet` and `outpost`. Each has `scout` (podinfo 6.15.0)
and `shuttle`. `outpost` also runs `probe` (go-httpbin 2.25.0) with no
resources. No ResourceQuota and no LimitRange exist. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-050-01
```

`astrona destroy` takes the environment name (`metadata.name`), not the config
path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition |
| `manifests/lab-start.yaml` | Namespaces and workloads |
| `docs/overview.md` | What the environment contains and ideas to try |
