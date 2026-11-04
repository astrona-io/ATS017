---
estimated_duration: 25m
---

# Solution

Inspect the local Git history, then set three ResourceQuotas. A ResourceQuota
caps the total resources in one namespace. A PersistentVolumeClaim (PVC)
requests storage; reducing a quota does not remove a claim that already exists.

| Goal | Where it lives | Field or command |
| --- | --- | --- |
| Find the reverted request | Local Git history | `git log -p` |
| Block new claims | Namespace quota | `persistentvolumeclaims: "0"` |
| Stop the storage consumer | Deployment | `kubectl scale` |
| Limit total requested storage | Namespace quota | `requests.storage` |

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/labs/lab-03
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

The checks are `storage-block`, `planned-limits-1` for `pipeline-scout` and
`planned-limits-2` for `pipeline-probe`. The starting state has no quotas, so
none should pass yet. The watch terminal shows the remaining failures after
each change. No command output is recorded here; use the
results from your own cluster.

## Step 1: Inspect the historical request

Read the commits and their patches:

```sh
cd /tmp/cnpe-pipeline-review
git log --oneline
git log -p -- pipelines
kubectl get pvc -A
```

Find the commit that adds `storage: 80Gi` and read its `metadata.namespace`.
Look for a later revert that removes the same change. The original request
names `pipeline-shuttle`; the working files return to `1Gi`. A revert adds
history, so looking only at the latest files misses the large request.

Then inspect which workload mounts the existing claim:

```sh
kubectl -n pipeline-shuttle get deployment cache-reader -o yaml
kubectl -n pipeline-shuttle get pods
```

Look for `spec.template.spec.volumes[].persistentVolumeClaim.claimName` and
match it to `pipeline-cache`. This observation step changes no checks.

## Step 2: Block new claims and remove the old consumer

Save this as `resourcequota-pipeline-shuttle.yaml` outside the review directory:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pipeline-storage
  namespace: pipeline-shuttle
spec:
  hard:
    persistentvolumeclaims: "0"
```

`apiVersion: v1` selects the core Kubernetes API. `kind` selects ResourceQuota.
`metadata` names the quota and its namespace. `spec.hard.persistentvolumeclaims`
sets the total allowed claim count to zero. It blocks new claims even before
you remove the existing one.

Apply it:

```sh
kubectl apply -f resourcequota-pipeline-shuttle.yaml
```

Then stop the Deployment and wait until its pods have been deleted:

```sh
kubectl -n pipeline-shuttle scale deployment/cache-reader --replicas=0
kubectl -n pipeline-shuttle wait --for=delete pod -l app=cache-reader --timeout=180s
kubectl -n pipeline-shuttle delete pvc pipeline-cache --timeout=180s
kubectl -n pipeline-shuttle get deployment,pods,pvc
kubectl -n pipeline-shuttle describe resourcequota pipeline-storage
```

The Deployment should remain at zero replicas, with no pods or claims left.
The PVC protection controller delays deletion while a pod object still uses
the claim. Scaling the Deployment down first removes that consumer. The quota
itself does not evict pods or remove storage.

The watch terminal now shows `storage-block` passing; it also attempts a real `1Mi`
PVC create and requires a quota rejection.

## Step 3: Limit count and total storage in the other namespaces

Save this as `resourcequota-pipeline-scout.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pipeline-storage
  namespace: pipeline-scout
spec:
  hard:
    persistentvolumeclaims: "2"
    requests.storage: 4Gi
```

The object uses the same API and kind. `metadata.namespace` selects
`pipeline-scout`. The two `spec.hard` entries allow at most two claims and a
combined storage request of `4Gi`, including the existing `1Gi` claim. No
`scopes` or `scopeSelector` narrows this quota.

Apply it:

```sh
kubectl apply -f resourcequota-pipeline-scout.yaml
```

Then check the result:

```sh
kubectl -n pipeline-scout describe resourcequota pipeline-storage
```

Look for both resources under used and hard. The watch terminal now shows
`planned-limits-1` passing. Its new `1Mi` claim fits, a second extra claim exceeds the
count, and a new `4Gi` claim exceeds the total while there is room in the count.

Save this as `resourcequota-pipeline-probe.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pipeline-storage
  namespace: pipeline-probe
spec:
  hard:
    persistentvolumeclaims: "3"
    requests.storage: 6Gi
```

`metadata.namespace` selects `pipeline-probe`. Its `spec.hard` entries allow
three claims and `6Gi` across their requests. The other fields have the same
role as in the first quota.

Apply it:

```sh
kubectl apply -f resourcequota-pipeline-probe.yaml
```

Then check the result:

```sh
kubectl -n pipeline-probe describe resourcequota pipeline-storage
kubectl -n pipeline-probe get deployment,pvc
```

Keep the original claim and the one-replica Deployment. The watch terminal now
shows `planned-limits-2` passing: two new `1Mi` claims fit, another exceeds the
count, and a new `6Gi` claim exceeds the total requested storage.

Press Ctrl-C to stop the watch, then run the plain command once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/labs/lab-03
```

The validator's temporary claims use `storageClassName: ""` and have no
consumer. They test API admission without requesting dynamic provisioning.
They need not bind to prove that the API server accepted them. The validator
removes its temporary claims after the checks.

## If a check stays red

- **`storage-block`: claim remains.** Check for consumer pods. Keep the
  Deployment at zero and wait for pods to disappear before deleting the claim.
  Do not remove PVC protection finalizers.
- **`planned-limits-1` or `planned-limits-2`: wrong quota.** Read `spec.hard` and
  `status.hard`. Confirm both count and storage, and allow the quota controller
  to update status before you submit.
- **An allowed claim is rejected.** Remove your own extra test claims. Keep
  only the original `1Gi` claim in each bounded namespace. The validator needs
  free capacity to prove that small claims are allowed.
- **The local Git history is missing.** Use `/tmp/cnpe-pipeline-review` on the
  terminal where bootstrap ran. Read the full patch history rather than only
  the current manifests.
