# Unsupported Access Modes

A PersistentVolumeClaim (PVC) is a namespaced request for storage by size and access mode. The API server accepts any valid claim, but a claim is only a request, and the storage behind it may not be able to meet it. The provisioner, the component that creates storage on demand, makes that decision later. This part asks for a mode that the playground's storage cannot provide and reads the event that explains the failure.

## A mode the storage cannot provide

An **access mode** describes the mounting pattern a volume supports: `ReadWriteOnce` (read-write from one node), `ReadOnlyMany` (read-only from many nodes), `ReadWriteMany` (read-write from many nodes) and `ReadWriteOncePod` (read-write by one pod in the cluster). Request `ReadWriteMany` from the `standard` StorageClass, the object that selects the provisioner and volume rules. The API server accepts the claim, but that does not prove the storage can serve it.

<!-- astrona:playground:renew -->

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

Remove the failed example:

```sh
kubectl -n starfleet delete pod scout-shared
kubectl -n starfleet delete pvc scout-shared
```

You should see something like:

```text
pod "scout-shared" deleted from starfleet namespace
persistentvolumeclaim "scout-shared" deleted from starfleet namespace
```

You have seen a claim that the API server accepts and the provisioner refuses. The `ProvisioningFailed` event in `kubectl describe pvc` names the unsupported access mode, and a larger size or another pod does not change it. Keeping a file through pod replacement is different from keeping it after the claim itself is deleted.

## Common pitfalls

> [!WARNING]
> - **Taking successful claim creation as successful provisioning.** Check the phase and events after a consumer exists.
> - **Fixing the wrong field.** A larger size or another pod does not fix an unsupported access mode; choose a supported mode or a suitable storage driver.
> - **Assuming every local provisioner supports `ReadWriteOncePod`.** This playground accepts it, but the portable choice is a driver using the Container Storage Interface (CSI).
