# Question

Solve this question on: `terminal`

The `probe` StatefulSet has two busybox Pods with separate data claims. Each claim already contains a unique record in `/data/record`. Its current retention policy deletes claims on scale-down and on StatefulSet deletion. The `standard` StorageClass also deletes storage after claim deletion.

## Tasks

1. Inspect the StatefulSet, the claims `data-probe-0` and `data-probe-1`, their bound volumes and their owner references. Read each Pod's `/data/record` before changing anything.
2. Change the StatefulSet's claim retention policy to retain claims both when scaled and when deleted. Wait until the claims no longer have deletion owner references.
3. Scale to one replica, verify that both claims remain Bound, then restore two replicas. Replace `probe-0` and confirm that both original records remain readable.

## Constraints

- Preserve the original StatefulSet, claim UIDs, bound volumes, Pod template and record contents.
- Keep the StorageClass and PV reclaim policies unchanged; changing them does not solve controller-driven claim deletion.
- Finish with two ready replicas. The grader repeats scale-down and Pod replacement, then restores two replicas.

Learner work: about 15 minutes. Allow separate time for cluster startup and Pod replacement.
