# Share Capacity With PriorityClasses And Quota Scopes

A ResourceQuota caps a namespace, but it does not decide which pod wins when the cluster is full. When two tenants compete for the last CPU on a node, the scheduler needs a rule. A PriorityClass is that rule: it gives pods a number, and the scheduler may evict pods with a lower number to place a pod with a higher number. This module teaches the PriorityClass, preemption, and the quota scopes that stop one tenant from abusing priority.

The key sentence of this module: **a PriorityClass decides who may evict whom, and a quota scope decides how many pods of each kind a namespace may run.**

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-02/playground
> ```

## Learning objectives

- Create PriorityClasses and assign them to pods with `priorityClassName`
- Observe a higher-priority pod preempt lower-priority pods on a full node and read the `Preempted` events
- Prevent preemption with `preemptionPolicy: Never`
- Limit how many high-priority pods a namespace may run with a `PriorityClass` quota scope
- Count only `BestEffort` or `Terminating` pods with quota scopes

## Before you start

You should know what a ResourceQuota is and how to read a request and a limit. The playground has one `kind` node with the namespaces `starfleet` and `outpost`. The `probe` Deployment in `outpost` has three replicas that request almost all the free CPU, so a new pod that asks for `300m` of CPU cannot fit. Only the built-in system PriorityClasses exist, and there is no ResourceQuota.

## What comes next

The module has three parts. **PriorityClass And Preemption** creates a PriorityClass and watches the scheduler evict pods to make room. **Preemption Policy Never** shows a high-priority pod that may not evict anything. **Quota Scopes** adds quota scopes to the namespace, so a namespace cannot run more than a fixed number of high-priority pods.
