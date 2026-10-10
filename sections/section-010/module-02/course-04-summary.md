# Summary

Where a pod runs is decided by rules from both sides: the pod chooses nodes, nodes refuse pods, and replicas look at each other. This module used each rule on a three-node cluster with two zones.

## What you learned

The scheduler places a pod in two steps. The filter step removes every node the pod may not use: too little room for the requests, an untolerated taint, an unmatched required affinity rule, or a spread rule that would be broken. The score step ranks the nodes that are left, and preferences only add points there. A preference can therefore never win against a filter. When no node passes, the pod stays `Pending` and its `FailedScheduling` event counts the reason for each node.

Placement rules match node labels. The well-known labels `kubernetes.io/hostname`, `kubernetes.io/arch`, `kubernetes.io/os` and `topology.kubernetes.io/zone` exist on every cluster; others, such as `disktype`, are set by an administrator. `nodeSelector` requires exact labels. Required node affinity (`requiredDuringSchedulingIgnoredDuringExecution`) is a filter with operators such as `In` and `NotIn`, and preferred node affinity only scores. Neither moves a pod that is already running.

A taint repels pods from a node with the effect `NoSchedule`, `PreferNoSchedule` or `NoExecute`, and a toleration lets a pod past it. A toleration permits but never attracts, so dedicating a node to a tenant takes a taint on the node plus a toleration and required node affinity on the tenant's pods.

Pod anti-affinity keeps matching pods out of a domain that already runs one, where the domain is defined by `topologyKey`; on `kubernetes.io/hostname` it means one pod per node, and the required form caps the replica count. A topology spread constraint limits the difference between domains to `maxSkew`. With `DoNotSchedule` it is a filter, and with `ScheduleAnyway` only a score. A scale-down does not respect it. The key facts to remember are these:

- Filters first, then scores; preferences cannot beat taints or required rules.
- A toleration plus node affinity dedicates a node; a toleration alone does not.
- Required anti-affinity on `kubernetes.io/hostname` allows one pod per node.
- `FailedScheduling` messages count the reason for every node; read them first.

<!-- astrona:playground:destroy -->
