# Route Traffic With The Gateway API — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-020-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with the
Gateway API standard CustomResourceDefinitions and an implementation installed
by the astrona `gatewayAPI` addon. The `starfleet` namespace has `bridge`,
`scout`, `probe` and `shuttle`. The `outpost` namespace has another `probe`.
No Gateway or HTTPRoute exists at the start.

The addon installs the Gateway API CRDs v1.6.1 (experimental channel) and
Envoy Gateway with the GatewayClass `eg`. A Gateway gets a ClusterIP address
in `status.addresses`; requests go from `shuttle`. `config.yaml` moves the
addon's host ports to 18080/18443 because 8080 is often taken.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-020-01
```

`astrona destroy` takes the environment name (`metadata.name` =
`ats-017-playground-020-01`), not the config path. `astrona submit` and
`astrona test` do not apply because there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, add-on, images and starting manifests) |
| `manifests/lab-start.yaml` | Namespaces, backends and the `shuttle` client |
| `docs/overview.md` | What the environment contains and ideas to try |
