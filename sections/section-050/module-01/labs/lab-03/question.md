---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

## Scenario

The Starfleet platform team runs three pipeline namespaces: `pipeline-scout`,
`pipeline-probe` and `pipeline-shuttle`. Each has a `1Gi` PersistentVolumeClaim
(PVC), a request for persistent storage, named `pipeline-cache`. Each
`cache-reader` Deployment maintains one pod that mounts that claim.

A local Git repository at `/tmp/cnpe-pipeline-review` records a request for an
`80Gi` pipeline cache. The team reverted that commit. The current files no
longer show the large request, but the namespace in that historical request
must lose all storage access. Git records file changes as commits; a revert
adds a commit that undoes an earlier change without removing its history.

The terminal has `git`. No remote repository or network access is needed for
the investigation.

## Tasks

1. **Find and block the historical target.** Inspect the local repository's
   history to identify the namespace in the reverted `80Gi` PVC request.
   Create a ResourceQuota named `pipeline-storage` there, with
   `persistentvolumeclaims: "0"`, so the API server rejects every new PVC.
   A ResourceQuota caps resources across a whole namespace.
2. **Remove its existing storage.** Scale that namespace's `cache-reader`
   Deployment to `0` replicas. Wait until its pods are gone, then delete its
   `pipeline-cache` PVC. Leave the Deployment present, with no pods or PVCs in
   that namespace. The lab's cache data is disposable.
3. **Bound the other pipelines.** The team planned these hard limits before the
   review. Create an unscoped ResourceQuota named `pipeline-storage` in each
   of the two namespaces that you did not block, with the limits from its row.
   The blocked namespace keeps the quota from task 1 and ignores its row:

   | Namespace | `persistentvolumeclaims` | `requests.storage` |
   | --- | --- | --- |
   | `pipeline-scout` | `"2"` | `4Gi` |
   | `pipeline-probe` | `"3"` | `6Gi` |
   | `pipeline-shuttle` | `"4"` | `8Gi` |

   Each quota must allow small new claims within both limits, reject a claim
   that takes the namespace over its total requested storage, and reject an
   extra claim once the count is full.

Keep the original `1Gi` `pipeline-cache` claims and the one-replica
`cache-reader` Deployments available in the two bounded namespaces. Leave only
those original claims there when you finish. Do not create other quotas,
LimitRanges or admission policies in the three namespaces.

The grader reads the quotas, Deployments and claims, then creates real temporary
PVCs and reads whether the API server accepts or rejects each one. It removes
its own temporary claims.
