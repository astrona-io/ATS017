# Default Classes And StatefulSet Claims

An application can request storage without naming a class. Kubernetes then assigns the cluster's default StorageClass, the object that selects the provisioner and volume rules. That makes application manifests shorter, but it also makes a cluster-wide default part of the application's storage behaviour.

## Change the default deliberately

The annotation `storageclass.kubernetes.io/is-default-class` marks the default class. An **annotation** is an object metadata value used by components rather than by label selectors. Make `standard-retain` the default and remove the default mark from `standard`.

<!-- astrona:playground:renew -->

```sh
kubectl annotate storageclass standard storageclass.kubernetes.io/is-default-class=false --overwrite
kubectl annotate storageclass standard-retain storageclass.kubernetes.io/is-default-class=true --overwrite
kubectl get storageclass
```

You should see something like:

```text
storageclass.storage.k8s.io/standard annotated
storageclass.storage.k8s.io/standard-retain annotated
NAME                        PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard                    rancher.io/local-path   Delete          WaitForFirstConsumer   false                  3m42s
standard-retain (default)   rancher.io/local-path   Retain          WaitForFirstConsumer   false                  3m24s
```

Only one class should normally be the default. If several are marked, Kubernetes selects the most recently created default class for a claim that omits its class. It does not use the time you last edited the annotation.

Create a PersistentVolumeClaim (PVC), a namespaced request for storage, with no `storageClassName` field:

Save this as `persistentvolumeclaim-shuttle-data.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shuttle-data
  namespace: starfleet
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 64Mi
```

Apply it:

```sh
kubectl apply -f persistentvolumeclaim-shuttle-data.yaml
```

You should see something like:

```text
persistentvolumeclaim/shuttle-data created
```

Then check the result:

```sh
kubectl -n starfleet get pvc shuttle-data -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,CLASS:.spec.storageClassName
```

You should see something like:

```text
NAME           PHASE     CLASS
shuttle-data   Pending   standard-retain
```

The API server assigned `standard-retain`. The claim stays `Pending` because the class waits for a consumer. Omitting `storageClassName` asks for the default; explicitly setting `storageClassName: ""` asks for no class and disables this default selection. A claim with no class set can also receive a default later if the cluster had none when it was created.

Changing the default does not move data or change the class on a bound claim. Name a class explicitly when the application's storage requirements must not depend on this cluster-wide setting.

## One claim per replica

A **StatefulSet** is a controller that gives each pod a stable name and can create separate claims for each replica. This avoids putting every replica on the same claim by mistake. Its `volumeClaimTemplates` field is a list of claim specifications that the controller turns into real claims.

The `probe` example has two replicas. A **headless Service**, a Service with `clusterIP: None`, gives its pods stable network names without a shared virtual address. The claim template explicitly chooses `standard-retain`, regardless of which class is default.

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

Restore the original cluster default when you finish the comparison:

```sh
kubectl annotate storageclass standard-retain storageclass.kubernetes.io/is-default-class=false --overwrite
kubectl annotate storageclass standard storageclass.kubernetes.io/is-default-class=true --overwrite
kubectl get storageclass
```

You should see something like:

```text
storageclass.storage.k8s.io/standard-retain annotated
storageclass.storage.k8s.io/standard annotated
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  3m54s
standard-retain      rancher.io/local-path   Retain          WaitForFirstConsumer   false                  3m36s
```

The `shuttle-data` claim still names `standard-retain`, and so do the StatefulSet's claims. Defaults affect class assignment, not existing bindings. You can now select a predictable class for a workload, give each replica its own storage, and distinguish claim retention from volume reclamation.

## Common pitfalls

> [!WARNING]
> - **Leaving two default classes by accident.** Kubernetes chooses by creation time; keep one default unless a migration needs more.
> - **Confusing an omitted class with an empty string.** Omission requests the default; `""` requests no class.
> - **Expecting scale-down to remove claims.** The StatefulSet's default claim retention policy keeps them.
> - **Confusing the two retention decisions.** StatefulSet retention controls claim deletion; the volume's reclaim policy controls storage after claim deletion.

## Your mission: Keep The Volume After Claim Deletion

You can now read a volume's reclaim policy, predict what claim deletion does, and set the default StorageClass. The mission gives you a claim on a `Delete` volume that holds a file. You change the policy on the existing volume without touching the claim or the pod, and you make `standard-retain` the default class.

Pause the playground first:

```sh
astrona stop ats-017-playground-020-03
```

Start the mission and send it for grading:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-03/labs/lab-02
astrona submit -c sections/section-020/module-03/labs/lab-02
```

When you finish, remove the mission cluster and resume the playground:

```sh
astrona destroy ats-017-lab-020-03-02
astrona start ats-017-playground-020-03
```
