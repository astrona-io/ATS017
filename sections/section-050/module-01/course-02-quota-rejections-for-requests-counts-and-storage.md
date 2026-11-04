# Quota Rejections For Requests, Counts And Storage

A ResourceQuota is a namespaced object that caps the total compute, storage and object counts of a namespace. A pod that asks for more than the quota has left is rejected, but the quota rejects other requests as well, and each one has its own message. This part reads three more rejections: a pod that declares nothing, a ConfigMap over the count, and a PersistentVolumeClaim over the storage cap.

## A compute quota needs requests on every pod

The commands below need the ResourceQuota `outpost-quota` in the `outpost` namespace, with `requests.cpu: 100m`, `requests.memory: 256Mi`, `limits.memory: 512Mi`, `pods: "10"`, `requests.storage: 2Gi`, `persistentvolumeclaims: "2"` and `count/configmaps: "3"`. The `scout` Deployment there runs one replica, and `probe` (`go-httpbin`) declares no resources.

<!-- astrona:playground:renew -->

Restart `probe`. Its pod template declares no resources, and the quota counts `requests.cpu`, `requests.memory` and `limits.memory`:

```sh
kubectl -n outpost rollout restart deploy/probe
kubectl -n outpost get deploy probe -o jsonpath='{.status.conditions[?(@.type=="ReplicaFailure")].message}{"\n"}'
```

You should see something like:

```text
deployment.apps/probe restarted
pods "probe-655cdd5cb4-2cwh9" is forbidden: failed quota: outpost-quota: must specify limits.memory for: probe; requests.cpu for: probe; requests.memory for: probe
```

This is a different message: `failed quota` and `must specify`. The pod asks for nothing, so there is no number to add to `used`, and the API server cannot check it against `hard`. Kubernetes closes this gap with a rule: **when a quota counts a compute resource, every new pod must declare that resource, or the API server rejects the pod.** The old `probe` pod keeps running, because the quota never touches existing pods. Only the new pod is rejected, so the rollout does not finish. A LimitRange, an object that sets default requests and limits for containers, fixes this without editing every Deployment.

## Object counts and storage

Counts and storage use the same check. Create three ConfigMaps. The namespace already has one, and the cap is three:

```sh
kubectl -n outpost create configmap notes-1 --from-literal=k=v
kubectl -n outpost create configmap notes-2 --from-literal=k=v
kubectl -n outpost create configmap notes-3 --from-literal=k=v
```

You should see something like:

```text
configmap/notes-1 created
configmap/notes-2 created
error: failed to create configmap: configmaps "notes-3" is forbidden: exceeded quota: outpost-quota, requested: count/configmaps=1, used: count/configmaps=3, limited: count/configmaps=3
```

Here the API server answers `kubectl` directly, because `kubectl` made the request itself. Storage works the same way. Save this as `pvc-big.yaml`. It asks for `3Gi`, and the quota allows `2Gi`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-big
  namespace: outpost
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 3Gi
```

Apply it:

```sh
kubectl apply -f pvc-big.yaml
```

You should see:

```text
Error from server (Forbidden): error when creating "pvc-big.yaml": persistentvolumeclaims "data-big" is forbidden: exceeded quota: outpost-quota, requested: requests.storage=3Gi, used: requests.storage=0, limited: requests.storage=2Gi
```

You can now tell the three rejection messages apart: `exceeded quota` for a full line, `must specify` for a pod that declares nothing the quota counts, and the `ReplicaFailure` condition that carries them for a Deployment. The same check caps object counts and storage, and `kubectl` shows the answer directly when it makes the request itself. The open question is how a tenant's pods get requests when the team forgets to write them.

## Common pitfalls

> [!WARNING]
> - **Forgetting the quota resource names.** `cpu` and `memory` are short for `requests.cpu` and `requests.memory`. Use the full names to avoid doubt. Object counts use `count/<resource>.<group>`, for example `count/deployments.apps`.
> - **Expecting the quota to stop the old pod.** A new pod without requests is rejected, but the old pod keeps running, so the rollout stalls instead of failing.
> - **Reading a count as a total.** The ConfigMap `kube-root-ca.crt` exists in every namespace and counts toward `count/configmaps`.

## Your mission: Limit Pipeline Storage With ResourceQuota

You can now use a quota to limit claim count and total requested storage. The mission asks you to inspect a reverted Git request, block storage in the pipeline namespace it names, remove that namespace's claim after stopping its consumer, and set storage limits in the other two namespaces.

Pause the playground first:

```sh
astrona stop ats-017-playground-050-01
```

Start the mission and send it for grading:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/labs/lab-03
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/labs/lab-03
```

When you finish, remove the mission cluster and resume the playground:

```sh
astrona destroy ats-017-lab-050-01-03
astrona start ats-017-playground-050-01
```
