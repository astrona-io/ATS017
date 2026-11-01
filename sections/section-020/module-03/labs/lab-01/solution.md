# Solution Walkthrough

The claim asks for `ReadWriteMany`. The `standard` StorageClass uses the `rancher.io/local-path` provisioner, which supports only `ReadWriteOnce` and `ReadWriteOncePod`. The provisioner fails, so the claim never binds and the pod never starts. You fix it by replacing the claim with a supported access mode.

---

## Step 1: Read why the pod and claim are not ready

List the pod and the claim:

```sh
kubectl -n starfleet get pods,pvc
```

The `scout` pod is `Pending` and `scout-data` is `Pending`. Read the claim's events:

```sh
kubectl -n starfleet describe pvc scout-data
```

Look for a `ProvisioningFailed` event. It names the access modes that the provisioner supports. This is different from the normal `WaitForFirstConsumer` message, which only says that a pod must use the claim first.

## Step 2: Replace the claim

The `accessModes` field of a claim cannot be edited. Stop the consumer first, because Kubernetes protects a claim that a pod still uses:

```sh
kubectl -n starfleet scale deploy/scout --replicas=0
kubectl -n starfleet wait --for=delete pod -l app=scout --timeout=120s
kubectl -n starfleet delete pvc scout-data
```

Save this as `persistentvolumeclaim-scout-data.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: scout-data
  namespace: starfleet
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 64Mi
```

Apply it:

```sh
kubectl apply -f persistentvolumeclaim-scout-data.yaml
```

## Step 3: Start the consumer and check

Scale the Deployment back up and wait for it:

```sh
kubectl -n starfleet scale deploy/scout --replicas=1
kubectl -n starfleet rollout status deploy/scout --timeout=180s
kubectl -n starfleet get pvc scout-data
```

The claim is `Bound`. Now prove that the data survives pod replacement:

```sh
kubectl -n starfleet exec deploy/scout -- sh -c 'echo saved-by-scout > /data/message.txt'
kubectl -n starfleet delete pod -l app=scout
kubectl -n starfleet rollout status deploy/scout --timeout=180s
kubectl -n starfleet exec deploy/scout -- cat /data/message.txt
```

The last command prints `saved-by-scout`.

## Step 4: Submit

```sh
astrona submit -c sections/section-020/module-03/labs/lab-01
```

## Why the other fixes fail

- **Switching to `emptyDir`.** The pod starts, but the file disappears when the pod is replaced. The grader checks that the Deployment uses the claim.
- **Making the claim bigger or adding a node.** The size and the node count are not the problem. The access mode is.
- **Editing the claim in place.** The API server rejects a change to `accessModes` on an existing claim.
