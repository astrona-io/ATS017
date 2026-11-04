# Set Resource Requests With The Vertical Pod Autoscaler

A workload's resource requests can drift away from its usage. The **Vertical Pod Autoscaler (VPA)** calculates CPU and memory recommendations from measured container usage. A **request** is the amount of a resource that the scheduler reserves for a container. You will use recommendations without allowing VPA to replace running Pods on its own.

The module has three parts. **Read Recommendations Without Changing Pods** creates a recommendation-only VPA for a Deployment, a controller that maintains replaceable Pods. **Bound Recommendations For A StatefulSet** sets a resource range for a controller whose Pods keep stable names. **Apply Recommendations At Pod Creation** replaces Pods deliberately and compares their running resources with their workload templates. The summary closes the module.

## Learning objectives

After this module you can:

- Write a `VerticalPodAutoscaler` for a Deployment and a StatefulSet.
- Read `status.recommendation` and bound CPU and memory with `minAllowed` and `maxAllowed`.
- Use `Initial`, compare every update mode in VPA 1.7.3, and identify deprecated `Auto`.
- Replace a Pod and prove that VPA applied its requests without changing the workload template.
- Keep VPA from competing with a Horizontal Pod Autoscaler and distinguish creation-time updates from in-place resize.

## Before you start

You need `kubectl get`, `apply`, `describe`, `delete` and `rollout`, plus requests, limits and workload templates. A **limit** caps a container's resource use: CPU is throttled and a process that exceeds its memory limit can be killed. CPU values use millicores, so `100m` means one tenth of a CPU core; `Mi` means mebibytes of memory.

The playground runs Kubernetes 1.35.8 and VPA 1.7.3. Its controller installation is plumbing. The terminal needs `kubectl`; environment preparation also needs Helm 4.x. The `starfleet` namespace contains Deployment `scout` and StatefulSet `probe`, both running podinfo 6.15.0. Each starts with requests of `500m` CPU and `512Mi` memory and limits of `1` CPU and `1Gi` memory. There are no autoscaler objects yet.

Write the example files in an empty working folder. Usage samples need time to accumulate. A short practice session teaches the API and the update path; it does not provide enough history for production sizing.

<!-- astrona:playground -->
