# Isolate Traffic With NetworkPolicy — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-020-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`). kind's
default CNI, kindnet, enforces NetworkPolicy (checked: ingress, egress,
`namespaceSelector` and DNS rules all behave as the course shows).
`starfleet` runs `scout`, `probe` and `shuttle`; `outpost` runs `probe` and a
second `shuttle`. No NetworkPolicy exists at the start.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-020-02
```

`astrona destroy` takes the environment name (`metadata.name` =
`ats-017-playground-020-02`), not the config path. There is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, preloaded images, starting manifests) |
| `manifests/lab-start.yaml` | Namespaces, workloads and Services |
| `docs/overview.md` | What the environment contains and ideas to try |
