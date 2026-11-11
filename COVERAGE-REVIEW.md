# Coverage review

The review adds a StatefulSet retention lab and separates oversized requests from OOM recovery. Cost questions now distinguish a fixed measurement period from an immutable response, and the cost-ranking lesson has a linked question. The storage playground tests the exact StatefulSet manifest from the lesson.

The OOM lab now follows QoS teaching. A separate cost-scaling lesson prepares the fixed-window ranking and replica change. The idle-cost lesson now correctly says that lower requests on a fixed node increase unused capacity.

The labs exercise requests, placement, Gateway API attachment and routing, NetworkPolicy, local storage, autoscaling, allocation and tenant controls. Practical limits remain:

- In-place resize tests the supported CPU change. Restart policies, stalled resizes and persistence in a controller template are supporting lessons rather than separately graded cases.
- The cost-scaling lab uses a bootstrap-confirmed ranking with synthetic on-premises prices. It does not prove lower cloud spend or implement a cost-aware autoscaler.
- kind's local storage proves persistence across Pod replacement, not recovery from a lost node or a cloud disk failure.
- Several cost exercises retain their existing 25-minute estimate because collecting and settling metrics takes time. Their duration has not been relabelled as a short exercise.

## Runtime choice

All current tasks use kind because their assessed behavior belongs to the Kubernetes API, controllers or cluster workloads. Separate environments keep different service meshes and policy configurations independent. Use QEMU for a future task that needs a separate kernel, VM boot behavior or a host service; none of these changes needs it.

## What verification establishes

The workflow checks registration and preparation order, then runs each selected environment on its own runner. A lab first requires API readiness and an explicit grader FAIL, applies its reference solution, runs all configured graders and tears down. The starting-state check stops at the first intentional rejection; it does not prove that every individual criterion fails initially. Shell errors, missing scripts, timeouts and inconsistent verdicts fail the test.

Playgrounds run bootstrap and readiness checks. A playground with testing/smoke.sh also runs that script. A successful playground start alone does not prove all learner commands. Network downloads, public registries and chart repositories remain external dependencies. Consult the PR's latest workflow for actual runtime results; this review and the generated map are not passing test reports.

## Assessment and procedure checks

CI checks quiz registration, answer references, unique question IDs, declared counts and links to earlier readings. Playground procedure tests cover the named examples above; other playgrounds still prove only startup and declared readiness unless they contain their own smoke script. These checks do not establish every command in every lesson.

## Readings without a module-lab link

The generated reverse map in [LAB-COVERAGE.md](LAB-COVERAGE.md) lists the current supporting and capstone-only readings. A listed concept is not claimed as independently assessed without a lab link.
