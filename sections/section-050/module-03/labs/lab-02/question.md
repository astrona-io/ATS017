---
estimated_duration: 30m
---

# Question

Solve this question on: `terminal`

Kyverno is installed in the cluster. The platform team wants every new tenant namespace to start with a quota and default resources. A namespace is a tenant when it has the label `tenant: "true"`.

Create a Kyverno `ClusterPolicy` with `generate` rules so that every namespace with the label `tenant: "true"` gets:

1.  A ResourceQuota named `tenant-quota` with `requests.cpu` `200m`, `requests.memory` `256Mi`, `limits.memory` `512Mi` and `pods` `10`.
2.  A LimitRange named `tenant-defaults` with one `Container` limit: default request `25m` CPU and `32Mi` memory, default memory limit `64Mi` and maximum memory limit `128Mi`.
3.  Both objects are created again if someone deletes them.

Constraints:

* A namespace without the label must get neither object.
* Do not create the quota or the LimitRange by hand in a fixed namespace. The grader creates new namespaces.

The grader creates one namespace with the label and one without, reads the generated objects, deletes the quota, creates a pod without resources and a pod with a `256Mi` memory limit, and reads the result of each.
