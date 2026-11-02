# Share Capacity With PriorityClasses And Quota Scopes — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-050-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with the
namespaces `starfleet` and `outpost`. `starfleet` runs `shuttle`. `outpost`
runs `probe` (go-httpbin 2.25.0) with three replicas whose CPU requests use
almost all the free CPU of the node, so a pod that requests `300m` cannot fit.
Only the built-in system PriorityClasses exist, and there is no ResourceQuota.
Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-050-02
```

`astrona destroy` takes the environment name (`metadata.name`), not the config
path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition |
| `manifests/lab-start.yaml` | Namespaces and `shuttle` |
| `bootstrap/fill-node.sh` | Creates `outpost/probe`, sized from the free CPU of the node |
| `docs/overview.md` | What the environment contains and ideas to try |
