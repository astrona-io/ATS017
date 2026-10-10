# Overview: Place Workloads With Affinity, Taints And Topology Spread (Playground)

This is a **playground**, not a lab. It starts a three-node cluster with labelled and tainted workers and a few workloads, and then waits. There is no task, no `astrona submit` and no pass or fail. Write placement rules, watch where pods land, `astrona destroy`, start over.

## What's in the box

- A `kind` cluster running Kubernetes 1.35 with three nodes. `kubectl` is already pointed at it. The node names start with `astro-ats-017-playground-010-02-`.

  | Node | Labels | Taint |
  | --- | --- | --- |
  | `...-control-plane` | `node-role.kubernetes.io/control-plane` | `node-role.kubernetes.io/control-plane:NoSchedule` |
  | `...-worker` | `topology.kubernetes.io/zone=zone-a`, `disktype=ssd` | none |
  | `...-worker2` | `topology.kubernetes.io/zone=zone-b` | `dedicated=outpost:NoSchedule` |

- Namespace **`starfleet`**: `scout` (`podinfo`, three replicas, no placement rules) and `shuttle` (a client pod with `curl`).
- Namespace **`outpost`**: `probe` (`go-httpbin`, an HTTP echo server), with no toleration.
- No PriorityClasses besides the built-in system classes.

## Helpers

Paste these once in each new terminal. `where_pods` prints the phase and node of every pod with the given `app` label in a namespace. `node_taints` prints the taints of every node. `why_pending` prints the latest `FailedScheduling` messages in a namespace.

```sh
where_pods() {
  kubectl -n "$1" get pods -l app="$2" -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName
}
node_taints() {
  kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
}
why_pending() {
  kubectl -n "$1" get events --field-selector reason=FailedScheduling --sort-by=.lastTimestamp | tail -5
}
```

Use them like this: `where_pods starfleet scout`, `node_taints`, `why_pending outpost`.

## Practice tasks

- Change the taint on the zone-b worker to `PreferNoSchedule` and recreate `scout`. Predict whether any replica lands in zone b before you look.
- Give `probe` a toleration with `operator: Exists` and only the key `dedicated`. Check that it still tolerates the taint.
- Replace the required anti-affinity in a copy of `scout` with the preferred form and five replicas. Count the pods per node.
- Write a spread constraint with `topologyKey: kubernetes.io/hostname` and compare its placement with a zone spread.
- Taint the zone-a worker with `NoExecute` for a few seconds and watch what happens to the running pods, then remove the taint.
