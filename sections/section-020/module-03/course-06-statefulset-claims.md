# StatefulSet Claims

A Deployment gives all its replicas the same pod template. If that template names one claim, every replica tries to use the same storage. An application with several replicas that each keep their own data needs one claim per replica. A StatefulSet solves this, and this part shows how its claims are named, bound and kept.

The examples use the `standard-retain` StorageClass, which has the reclaim policy `Retain`.

## One claim per replica

A **StatefulSet** is a controller that gives each pod a stable name and can create separate claims for each replica. This avoids putting every replica on the same claim by mistake. Its `volumeClaimTemplates` field is a list of claim specifications that the controller turns into real claims.

The `probe` example has two replicas. A **headless Service**, a Service with `clusterIP: None`, gives its pods stable network names without a shared virtual address. The claim template explicitly chooses `standard-retain`, regardless of which class is default.


<!-- astrona:playground:renew -->

Save this as `statefulset-probe.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: probe
  namespace: starfleet
spec:
  clusterIP: None
  selector:
    app: probe
  ports:
    - name: http
      port: 8080
      targetPort: http
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: probe
  namespace: starfleet
spec:
  serviceName: probe
  replicas: 2
  selector:
    matchLabels:
      app: probe
  template:
    metadata:
      labels:
        app: probe
    spec:
      containers:
        - name: probe
          image: mccutchen/go-httpbin:2.25.0
          ports:
            - name: http
              containerPort: 8080
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              memory: 64Mi
          volumeMounts:
            - name: data
              mountPath: /data
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        storageClassName: standard-retain
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 64Mi
```

Apply it:

```sh
kubectl apply -f statefulset-probe.yaml
```

You should see something like:

```text
service/probe created
statefulset.apps/probe created
```

Then check the result:

```sh
kubectl -n starfleet rollout status statefulset/probe --timeout=120s
kubectl -n starfleet get pods -l app=probe -o custom-columns=NAME:.metadata.name,CLAIM:.spec.volumes[0].persistentVolumeClaim.claimName
kubectl -n starfleet get pvc data-probe-0 data-probe-1 -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,CLASS:.spec.storageClassName
```

You should see something like:

```text
Waiting for 2 pods to be ready...
Waiting for 1 pods to be ready...
Waiting for 1 pods to be ready...
partitioned roll out complete: 2 new pods have been updated...
NAME      CLAIM
probe-0   data-probe-0
probe-1   data-probe-1
NAME           PHASE   CLASS
data-probe-0   Bound   standard-retain
data-probe-1   Bound   standard-retain
```

The controller created `data-probe-0` for `probe-0` and `data-probe-1` for `probe-1`. The claim name combines the template name, the StatefulSet name and the pod's ordinal, its stable index starting at zero. Each claim binds to its own PersistentVolume (PV), a cluster object representing storage.

The template name `data` also supplies the volume name used by `volumeMounts`. Unlike a standalone pod, this pod template does not need a fixed `claimName` in `spec.volumes`. The StatefulSet controller fills in the replica's claim reference. The sample application does not write its responses to `/data`; the mount demonstrates how to attach independent storage, not application-level replication.

## Scale down without deleting the claims

Reduce the StatefulSet to one replica and wait for `probe-1` to disappear:

```sh
kubectl -n starfleet scale statefulset probe --replicas=1
kubectl -n starfleet wait --for=delete pod/probe-1 --timeout=120s
kubectl -n starfleet get pvc data-probe-0 data-probe-1 -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,CLASS:.spec.storageClassName
```

You should see something like:

```text
statefulset.apps/probe scaled
pod/probe-1 condition met
NAME           PHASE   CLASS
data-probe-0   Bound   standard-retain
data-probe-1   Bound   standard-retain
```

Both claims remain `Bound`. By default, a StatefulSet retains its claims when scaled down or deleted. Increasing the replica count again lets `probe-1` reuse its existing claim rather than creating empty storage.

The field `spec.persistentVolumeClaimRetentionPolicy` can change this behaviour with `whenScaled` and `whenDeleted`, each set to `Retain` or `Delete`. That policy controls whether the controller deletes claims. The PV reclaim policy controls what happens to storage after a claim is deleted. Here the two defaults act at different steps: the controller keeps the claim, so the volume's reclaim policy is not triggered at all.

You can now give each replica its own claim with `volumeClaimTemplates`, read the claim names a StatefulSet creates, and explain why a scale-down leaves the claims `Bound`. Two controls now sit side by side: the StatefulSet retention policy decides whether the claim is deleted, and the volume's reclaim policy decides what happens to the storage after the claim is deleted.

## Common pitfalls

> [!WARNING]
> - **Expecting scale-down to remove claims.** The StatefulSet's default claim retention policy keeps them.
> - **Confusing the two retention decisions.** StatefulSet retention controls claim deletion; the volume's reclaim policy controls storage after claim deletion.

## Repair an explicit deletion policy

The independent lab uses busybox Pods so you can write and read a record on each claim. It starts with both retention fields set to `Delete`. Before scaling, change the controller's policy:

```sh
kubectl -n starfleet patch statefulset probe --type=merge -p '{"spec":{"persistentVolumeClaimRetentionPolicy":{"whenScaled":"Retain","whenDeleted":"Retain"}}}'
kubectl -n starfleet get pvc data-probe-0 data-probe-1 -o yaml
```

Wait until the claims' `metadata.ownerReferences` entries have been removed by the controller. Record each claim's UID and `spec.volumeName`, then scale down and back up. Use `kubectl exec probe-1 -- cat /data/record` in `starfleet` to confirm the original bytes remain. Delete `probe-0`, wait for its replacement and repeat the read. A new Pod UID with the same claim UID and content demonstrates storage continuity. Changing only the PV reclaim policy would not preserve the claim itself.
