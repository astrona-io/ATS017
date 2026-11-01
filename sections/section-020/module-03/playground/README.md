# Provision Storage With StorageClasses — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-017-playground-020-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with
StorageClasses `standard` and `standard-retain`. Both use delayed binding;
their reclaim policies are `Delete` and `Retain`. Namespace `starfleet`
starts with only the `shuttle` client. No claims or storage consumers are
applied at startup. The small workload images are preloaded.

## Run it

```sh
astrona run -c .
astrona destroy ats-017-playground-020-03
```

`astrona destroy` takes the environment name from `metadata.name`, not the
configuration path. Destroying the playground removes all its local data,
including storage whose volume reclaim policy is `Retain`.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, images, startup manifests and readiness |
| `manifests/lab-start.yaml` | Namespace, client and additional StorageClass |
| `examples/statefulset-probe.yaml` | Unapplied reference manifest for one claim per replica |
| `docs/overview.md` | Environment contents, helpers and practice ideas |

## Verified behaviour

Booted on Kubernetes 1.35.8. Claims wait for a consumer; files survive pod
replacement; two pods share `ReadWriteOnce` on the same node. This
environment also binds `ReadWriteOncePod` and prevents a second consumer
from scheduling. `ReadWriteMany` provisioning fails. Claim deletion removes
`Delete` volumes and leaves `Retain` volumes `Released`. StatefulSet
scale-down retains claims by default. Course command transcripts are kept
in the shared author scratchpad.
