---
estimated_duration: 20m
---

# Question

Solve this question on: `terminal`

The namespace `outpost` runs the Deployment `beacon` with two pods. The pods use the PriorityClass `platform-high`. The platform team wants to cap high-priority use in `outpost`, and to stop pods that declare no resources. Ordinary pods must keep working.

Add ResourceQuotas to the namespace `outpost` so that:

1.  The namespace cannot run more than `2` pods of the class `platform-high`. The two `beacon` pods keep running.
2.  A pod in `outpost` that declares no requests and no limits is rejected by a quota.
3.  An ordinary pod in `outpost` with requests and no PriorityClass is still accepted.

Constraints:

* Do not delete or scale `beacon`, and do not change or delete the PriorityClass `platform-high`.
* Do not create a quota in the namespace `starfleet`. A `platform-high` pod there must stay allowed.
* Do not use a quota without a scope for the pod limit. It would count ordinary pods too.

The grader creates a third `platform-high` pod, a pod without resources and an ordinary pod in `outpost`, and a `platform-high` pod in `starfleet`, and reads the result of each.
