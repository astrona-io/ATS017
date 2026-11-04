# Section 050: Multi-Tenancy Resources

This section shows how to share one cluster between teams. Each tenant namespace gets a quota and default container resources, priorities decide which pods run when the cluster is full, and Kyverno policies enforce the rules and create them for each new tenant. It comes last because it combines requests, placement and cost into rules for many teams.

**Curriculum item covered:** Optimizing Multi-Tenancy Resource Usage

---

## What You Will Master

- Cap the total CPU and memory requests and limits and the object counts of a namespace with a ResourceQuota
- Read used against hard in `kubectl describe resourcequota`
- Diagnose a pod or ReplicaSet rejected by a quota from the `Forbidden` message and the ReplicaSet events
- Set default requests and limits and the per-container minimum and maximum with a LimitRange
- Explain why a compute quota requires every new pod to declare requests, and how a LimitRange default solves that
- Create PriorityClasses and assign them to pods with `priorityClassName`
- Observe a higher-priority pod preempt lower-priority pods on a full node and read the `Preempted` events
- Prevent preemption with `preemptionPolicy: Never`
- Limit the pods of one PriorityClass in a namespace with a quota `scopeSelector`, and count only `BestEffort` pods with a quota scope
- Write a Kyverno validate policy, switch it between `Enforce` and `Audit`, and read the PolicyReport
- Write a Kyverno generate rule that creates a ResourceQuota and a LimitRange in every tenant namespace

---

## The Learning Path

### 1. Bound Tenants With ResourceQuota And LimitRange
*   **Hands-on Playground:** `sections/section-050/module-01/playground` — Single-node kind cluster. Namespaces `starfleet` and `outpost`, each with `scout` and `shuttle`. `outpost` has a `probe` Deployment without resources. No ResourceQuota or LimitRange exists at the start.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/playground
    ```

*   **Graded Lab:** Limit Pipeline Storage With ResourceQuota — `sections/section-050/module-01/labs/lab-03`. Inspect a reverted Git request to identify a pipeline namespace, block new claims and remove its existing storage, then cap claim count and total requested storage in two other namespaces. The task takes about 25 minutes.

### 2. Share Capacity With PriorityClasses And Quota Scopes
*   **Hands-on Playground:** `sections/section-050/module-02/playground` — Single-node kind cluster. `outpost` runs `probe` replicas that request almost all the free CPU, so a new pod cannot fit. A `scout-critical` Deployment manifest is ready to apply. Only the built-in system PriorityClasses exist, and there is no ResourceQuota.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-02/playground
    ```

### 3. Enforce Tenant Rules With Kyverno
*   **Hands-on Playground:** `sections/section-050/module-03/playground` — Single-node kind cluster with Kyverno installed by Helm (chart 3.9.2, Kyverno v1.19.2). The namespaces `starfleet` and `outpost` exist. No policy exists at the start.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-03/playground
    ```

### Section Capstone Challenge
*   **Comprehensive Challenge:** Multi-Tenancy Capstone — `sections/section-050/capstone/labs/lab-01`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/capstone/labs/lab-01
    astrona submit -c sections/section-050/capstone/labs/lab-01
    ```
*   **Hands-on Objective:** Two tenants share one node. The reader creates a PriorityClass so a critical `starfleet` pod preempts an `outpost` pod, sets LimitRange defaults so pods rejected by the `outpost` quota run, and adds a scoped quota that keeps the PriorityClass out of `outpost`. Admission errors, pod status and preemption events prove each step.
