# Persistent Data And ReadWriteOnce

The `scout-storage` pod mounts the `scout-data` PersistentVolumeClaim (PVC), a namespaced storage request, at `/data`. Write a file there, replace the pod, and read it again. That test separates storage held by the claim from the container's own writable file system.

## Replace a pod without losing the file

The commands below need `scout-data` bound and `scout-storage` running with that mount. Write a short message and check it before making any change.

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet exec scout-storage -- sh -c 'echo saved-by-scout > /data/message.txt'
kubectl -n starfleet exec scout-storage -- cat /data/message.txt
```

You should see something like:

```text
saved-by-scout
```

Now delete the pod, recreate it from the same manifest, and read the file:

```sh
kubectl -n starfleet delete pod scout-storage
kubectl apply -f pod-scout-storage.yaml
kubectl -n starfleet wait --for=condition=Ready pod/scout-storage --timeout=120s
kubectl -n starfleet exec scout-storage -- cat /data/message.txt
```

You should see something like:

```text
pod "scout-storage" deleted from starfleet namespace
pod/scout-storage created
pod/scout-storage condition met
saved-by-scout
```

The kubelet, the Kubernetes agent on the node, mounts the same PersistentVolume (PV), the object representing the claim's storage, into the replacement pod. The file survives because deleting a pod does not delete its claim. A container restart also keeps the mounted volume. In contrast, an `emptyDir` volume survives container restarts within one pod but is removed when that pod is removed.

Deletion can take about 30 seconds while Kubernetes gives the container time to stop. Wait for deletion to finish before recreating a standalone pod with the same name. Changing a pod manifest does not make Kubernetes recreate that pod automatically.

## One node is not one pod

An **access mode** describes the mounting pattern a volume supports. `ReadWriteOnce` limits read-write mounts to one node, not to one pod. Prove this with a second pod on the playground's single node.

Save this as `pod-scout-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: scout-reader
  namespace: starfleet
spec:
  containers:
    - name: writer
      image: busybox:1.37
      command: ["sh", "-c", "while true; do sleep 30; done"]
      resources:
        requests:
          cpu: 5m
          memory: 8Mi
        limits:
          memory: 32Mi
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: scout-data
```

Apply it:

```sh
kubectl apply -f pod-scout-reader.yaml
```

You should see something like:

```text
pod/scout-reader created
```

Then check the result:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/scout-reader --timeout=120s
kubectl -n starfleet exec scout-reader -- cat /data/message.txt
```

You should see something like:

```text
pod/scout-reader condition met
saved-by-scout
```

Two pods can now read the same file. The claim does not coordinate their writes. An application that shares storage must still prevent conflicting updates itself.

Choose a mode from the application's needs and the driver's supported modes:

| Mode | Mounting pattern | Typical need |
| --- | --- | --- |
| `ReadWriteOnce` | Read-write from one node; multiple pods on that node may share it | Storage for one application instance, or instances kept on one node |
| `ReadOnlyMany` | Read-only from many nodes | Shared reference files |
| `ReadWriteMany` | Read-write from many nodes | Shared files used by replicas on different nodes |
| `ReadWriteOncePod` | Read-write by one pod across the cluster | A single writer that must exclude other pods |

Kubernetes uses access modes when matching claims and volumes. `ReadOnlyMany` alone does not enforce file permissions; use a read-only mount and the storage system's controls where needed. The portable choice for `ReadWriteOncePod` is a driver using the **Container Storage Interface** (CSI), the standard interface between Kubernetes and storage drivers.

## A mode the storage cannot provide

Request `ReadWriteMany` from the `standard` StorageClass, the object that selects the provisioner and volume rules. The API server accepts the claim, but that does not prove the storage can serve it.

Save this as `persistentvolumeclaim-scout-shared.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: scout-shared
  namespace: starfleet
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 64Mi
```

Apply it:

```sh
kubectl apply -f persistentvolumeclaim-scout-shared.yaml
```

You should see something like:

```text
persistentvolumeclaim/scout-shared created
```

The class waits for a consuming pod. Create one so the provisioner actually attempts the request.

Save this as `pod-scout-shared.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: scout-shared
  namespace: starfleet
spec:
  containers:
    - name: writer
      image: busybox:1.37
      command: ["sh", "-c", "while true; do sleep 30; done"]
      resources:
        requests:
          cpu: 5m
          memory: 8Mi
        limits:
          memory: 32Mi
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: scout-shared
```

Apply it:

```sh
kubectl apply -f pod-scout-shared.yaml
```

You should see something like:

```text
pod/scout-shared created
```

Then check the result. The wait below times out deliberately; follow it with the description command to read why:

```sh
kubectl -n starfleet wait --for=jsonpath='{.status.phase}'=Bound pvc/scout-shared --timeout=15s
kubectl -n starfleet describe pvc scout-shared
```

The output, shortened to the timeout and the failure event, is:

```text
error: timed out waiting for the condition on persistentvolumeclaims/scout-shared
  Warning  ProvisioningFailed    0s (x2 over 15s)  rancher.io/local-path_local-path-provisioner-67b778fdf6-q4svb_e4567a89-8a64-4744-9f5c-fe4ea6bec210  failed to provision volume with StorageClass "standard": NodePath only supports ReadWriteOnce and ReadWriteOncePod (1.22+) access modes
```

The provisioner reports `ProvisioningFailed`, rather than the normal wait for a consumer. It cannot provide multi-node shared storage here. A larger size or another pod would not fix an unsupported access mode; choose a supported mode or a suitable storage driver.

The error also names `ReadWriteOncePod`. This playground does accept that mode: a checked claim bound, its first pod ran, and the scheduler refused a second pod using it. Treat that as verified behaviour of this environment, rather than assuming every local storage implementation supports it.

Remove the failed example before continuing:

```sh
kubectl -n starfleet delete pod scout-shared
kubectl -n starfleet delete pvc scout-shared
```

You should see something like:

```text
pod "scout-shared" deleted from starfleet namespace
persistentvolumeclaim "scout-shared" deleted from starfleet namespace
```

You have proved that files survive pod replacement and that `ReadWriteOnce` can serve two pods on one node. An access mode describes what the storage can do, and the claim only states what the application wants. The open question is what happens when the claim asks for a mode the storage cannot provide.

## Common pitfalls

> [!WARNING]
> - **Reading `ReadWriteOnce` as one pod.** It means one node; use `ReadWriteOncePod` when exclusive pod access is required and supported.
> - **Writing outside the mount.** Only files under `/data` use this claim; a file in the container's writable layer does not survive container replacement.
> - **Treating local persistent storage as a backup.** Losing the node or destroying the playground loses its local data.
