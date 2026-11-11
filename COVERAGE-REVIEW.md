# Coverage review

The OOM lab now follows QoS teaching. A separate cost-scaling lesson prepares the fixed-window ranking and replica change. The idle-cost lesson now correctly says that lower requests on a fixed node increase unused capacity.

The labs exercise requests, placement, Gateway API attachment and routing, NetworkPolicy, local storage, autoscaling, allocation and tenant controls. Practical limits remain:

- Gateway filters, StatefulSet claim lifecycle and address-range policy behavior have no dedicated module lab.
- In-place resize tests the supported CPU change. Restart policies, stalled resizes and persistence in a controller template are supporting lessons rather than separately graded cases.
- The cost-scaling lab uses a bootstrap-confirmed ranking with synthetic on-premises prices. It does not prove lower cloud spend or implement a cost-aware autoscaler.
- kind's local storage proves persistence across Pod replacement, not recovery from a lost node or a cloud disk failure.
- Several cost exercises retain their existing 25-minute estimate because collecting and settling metrics takes time. Their duration has not been relabelled as a short exercise.

## Runtime choice

All current tasks use kind because their assessed behavior belongs to the Kubernetes API, controllers or cluster workloads. Separate environments keep different service meshes and policy configurations independent. Use QEMU for a future task that needs a separate kernel, VM boot behavior or a host service; none of these changes needs it.

## What verification establishes

The workflow checks registration and preparation order, then runs each selected environment on its own runner. A lab first requires API readiness and an explicit grader FAIL, applies its reference solution, runs all configured graders and tears down. The starting-state check stops at the first intentional rejection; it does not prove that every individual criterion fails initially. Shell errors, missing scripts, timeouts and inconsistent verdicts fail the test.

Playgrounds run bootstrap and readiness checks. A playground with testing/smoke.sh also runs that script. A successful playground start alone does not prove all learner commands. Network downloads, public registries and chart repositories remain external dependencies. Consult the PR's latest workflow for actual runtime results; this review and the generated map are not passing test reports.

## Readings without a module-lab link

These remain visible in the reverse map. Some are supporting concepts or integrated in a section capstone; none is claimed as an independently graded skill merely because it appears in a reading.

- [course-04-node-capacity-and-pending-pods](sections/section-010/module-01/course-04-node-capacity-and-pending-pods.md)
- [course-03-spreading-replicas](sections/section-010/module-02/course-03-spreading-replicas.md)
- [course-07-filters-headers-rewrites-and-redirects](sections/section-020/module-01/course-07-filters-headers-rewrites-and-redirects.md)
- [course-05-named-ports-and-address-ranges](sections/section-020/module-02/course-05-named-ports-and-address-ranges.md)
- [course-06-statefulset-claims](sections/section-020/module-03/course-06-statefulset-claims.md)
- [course-04-resize-policy-and-resizes-that-do-not-finish](sections/section-030/module-02/course-04-resize-policy-and-resizes-that-do-not-finish.md)
- [course-05-making-the-change-permanent](sections/section-030/module-02/course-05-making-the-change-permanent.md)
- [course-06-right-sizing-next-to-an-hpa](sections/section-030/module-02/course-06-right-sizing-next-to-an-hpa.md)
- [course-02-preemption-policy-never](sections/section-050/module-02/course-02-preemption-policy-never.md)
