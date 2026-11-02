# Overview: Bound Tenants With ResourceQuota And LimitRange (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with two tenant namespaces and then waits. There is no task, no `astrona submit` and no pass or fail.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it.
- Namespace **`starfleet`**: `scout` (requests `20m` CPU and `32Mi` memory, memory limit `64Mi`) and `shuttle` (requests `10m`/`16Mi`, memory limit `32Mi`).
- Namespace **`outpost`**: the same `scout` and `shuttle`, and `probe` (`mccutchen/go-httpbin:2.25.0`) with no resources at all.
- No ResourceQuota and no LimitRange.

## Practice tasks

- Add a ResourceQuota to `starfleet` that caps `requests.cpu` at `60m`, then scale `scout` until the Deployment stops. Read the `ReplicaFailure` condition.
- Restart `probe` in `outpost` after you add a quota that counts `requests.memory`, and read the `must specify` message.
- Add a LimitRange with `defaultRequest` and `default`, restart `probe`, and compare the QoS class before and after.
- Set a LimitRange `max` for memory and create a pod above it. Read every rule in the message.
- Create a quota with `count/deployments.apps: "2"` and create a third Deployment.
- Apply a quota with `requests.storage: 1Gi` and create a PVC of `2Gi`.
