# Place Workloads With Affinity, Taints And Topology Spread — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-010-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A three-node kind cluster (one control plane, two workers; Kubernetes 1.35,
`kindest/node:v1.35.8`). `bootstrap/prepare.sh` labels the workers
`topology.kubernetes.io/zone=zone-a` (plus `disktype=ssd`) and `zone-b`, and
taints the zone-b worker `dedicated=outpost:NoSchedule`. `starfleet` runs
`scout` (3 replicas, no placement rules) and `shuttle`; `outpost` runs `probe`
without a toleration. The two extra nodes cost memory; one cluster at a time.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-010-02
```

`astrona destroy` takes the environment name (`metadata.name` =
`ats-017-playground-010-02`), not the config path. There is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (three nodes, preloaded images, bootstrap) |
| `bootstrap/prepare.sh` | Node labels and the taint (runs before the manifests) |
| `manifests/lab-start.yaml` | Namespaces, `scout`, `shuttle` and `outpost/probe` |
| `docs/overview.md` | What the environment contains and ideas to try |
