# Enforce Tenant Rules With Kyverno — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-050-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with
Kyverno installed by Helm (chart `kyverno/kyverno` 3.9.2, Kyverno v1.19.2, one
replica of the admission, background and reports controllers). Two tenant
namespaces, `starfleet` and `outpost`, run `scout` (podinfo 6.15.0) and
`shuttle`. `outpost` also runs `probe` (go-httpbin 2.25.0) with no resources.
No Kyverno policy exists yet. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-050-03
```

`astrona destroy` takes the environment name (`metadata.name`), not the config
path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition |
| `manifests/lab-start.yaml` | Namespaces and workloads |
| `bootstrap/prepare.sh` | Applies the manifests and installs Kyverno with Helm |
| `bootstrap/kyverno-values.yaml` | Helm values: one replica each, no cleanup controller |
| `docs/overview.md` | What the environment contains and ideas to try |
