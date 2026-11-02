# Changing The Default StorageClass

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

Changing the default is a cluster-wide decision, so put it back once you have seen the effect. Restore the original cluster default:

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

The `shuttle-data` claim still names `standard-retain`. Defaults affect class assignment, not existing bindings. You can now read which class is the default, change it with the annotation, and predict which class a claim without `storageClassName` receives. The next question is how a workload with several replicas gets a separate claim for each replica.

## Common pitfalls

> [!WARNING]
> - **Leaving two default classes by accident.** Kubernetes chooses by creation time; keep one default unless a migration needs more.
> - **Confusing an omitted class with an empty string.** Omission requests the default; `""` requests no class.

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
