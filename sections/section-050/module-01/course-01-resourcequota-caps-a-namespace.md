# ResourceQuota Caps A Namespace

Without a quota, a tenant can ask for any number of pods and any amount of CPU. The scheduler places each pod if a node has room, and it does not ask whether the tenant has had its fair share. This part puts a ResourceQuota on the namespace `outpost` and reads what the API server answers when the tenant asks for too much.

## What a ResourceQuota counts

A ResourceQuota has one important field, `spec.hard`. It lists the resources to cap and the maximum for each. Kubernetes tracks the sum of what the namespace uses for every listed resource and shows it as `used`. There are three groups of resources:

- **Compute:** `requests.cpu`, `requests.memory`, `limits.cpu` and `limits.memory`. They add up the requests and limits of all containers in all pods of the namespace that are not finished.
- **Storage:** `requests.storage` adds up the size of all PersistentVolumeClaims (PVCs, requests for storage). `persistentvolumeclaims` counts them. A name like `standard.storageclass.storage.k8s.io/requests.storage` caps one StorageClass.
- **Object counts:** `pods` counts pods. `count/<resource>` counts any namespaced object, for example `count/configmaps` or `count/deployments.apps`.

The API server checks the quota when a request creates an object. This check is an admission step, the part of the API server that accepts or rejects a request after authentication and before it stores the object. If the new object would push `used` above `hard`, the API server rejects the request with `Forbidden`. Objects that already exist are never stopped or deleted when a quota is added or lowered. The quota only decides about new objects.

## Create a quota and read it

The quota below caps CPU requests at `100m` for the whole namespace, which is small on purpose. It also caps memory, the number of pods, the total size and number of PVCs, and the number of ConfigMaps.

<!-- astrona:playground:renew -->

First, see what `outpost` runs today. The `probe` pod declares no resources, so Kubernetes gives it the QoS class `BestEffort` (the class for pods with no requests and no limits):

```sh
kubectl -n outpost get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```

You should see something like:

```text
NAME                       QOS
probe-6888d5d7d4-qgvwr     BestEffort
scout-6db96cb88c-srm95     Burstable
shuttle-5c44b786bb-mtxmk   Burstable
```

Nothing limits this namespace. Save this as `resourcequota-outpost.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: outpost-quota
  namespace: outpost
spec:
  hard:
    requests.cpu: 100m
    requests.memory: 256Mi
    limits.memory: 512Mi
    pods: "10"
    requests.storage: 2Gi
    persistentvolumeclaims: "2"
    count/configmaps: "3"
```

Apply it:

```sh
kubectl apply -f resourcequota-outpost.yaml
```

Then read used against hard:

```sh
kubectl -n outpost describe resourcequota outpost-quota
```

You should see something like:

```text
Name:                   outpost-quota
Namespace:              outpost
Resource                Used  Hard
--------                ----  ----
count/configmaps        1     3
limits.memory           96Mi  512Mi
persistentvolumeclaims  0     2
pods                    3     10
requests.cpu            30m   100m
requests.memory         48Mi  256Mi
requests.storage        0     2Gi
```

The `Used` column counted the three pods that already run. `scout` requests `20m` and `shuttle` requests `10m`, which makes `30m`. `probe` has no request, so it adds `0`. The one ConfigMap is `kube-root-ca.crt`, which Kubernetes creates in every namespace. This `describe` output is the first thing to read in any quota task.

## Read a rejection from a Deployment

A Deployment does not create pods itself. Its ReplicaSet creates them, so the rejection does not appear in your terminal. Scale `scout` to eight replicas. Each one requests `20m`, so only four more fit under `100m`:

```sh
kubectl -n outpost scale deploy/scout --replicas=8
kubectl -n outpost get deploy scout
kubectl -n outpost get deploy scout -o jsonpath='{.status.conditions[?(@.type=="ReplicaFailure")].message}{"\n"}'
```

You should see something like:

```text
deployment.apps/scout scaled
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
scout   4/8     4            4           12s
pods "scout-6db96cb88c-7fbm6" is forbidden: exceeded quota: outpost-quota, requested: requests.cpu=20m, used: requests.cpu=90m, limited: requests.cpu=100m
```

The Deployment sits at `4/8` and stays there. The `ReplicaFailure` condition of the Deployment holds the message of the last rejected pod. The message has a fixed shape: which quota, which resource, how much the new pod asks for (`requested`), how much is in use (`used`) and the cap (`limited`). The ReplicaSet also writes this message as a `FailedCreate` event, which `kubectl describe rs` shows. These two places, the condition and the events, are where to look when a Deployment has fewer pods than it should.

Set the Deployment back to one replica before the next step:

```sh
kubectl -n outpost scale deploy/scout --replicas=1
```

You can now cap a namespace with a ResourceQuota, read used against hard, and find a quota rejection for a Deployment in its `ReplicaFailure` condition. The rejection you read was a full line: a new pod asked for more than the quota had left. A pod that asks for nothing is rejected too, and it gets a different message.

## Common pitfalls

> [!WARNING]
> - **Looking for the rejection in the wrong place.** A rejected Deployment pod never reaches your terminal. Read the `ReplicaFailure` condition of the Deployment or the events of its ReplicaSet.
> - **Expecting a new quota to stop running pods.** A quota only decides about new objects. Existing pods count in `used` but keep running, even when `used` is above `hard`.
> - **Lowering requests during a rolling update with a full quota.** A rolling update creates new pods before it removes old ones. When the quota is full, the new ReplicaSet cannot create more pods, and the old ReplicaSet cannot shrink below the minimum available count. In a test, a Deployment of four pods requesting `200m` under a `500m` quota stopped at `3/4` ready after its request was lowered to `100m`. Use the `Recreate` strategy, or delete old pods, to break the stall.

## Your mission: Fit A Deployment Inside A ResourceQuota

You can now read a quota rejection and see which line of the quota is full. The mission gives you a Deployment that asks for more CPU than its namespace quota allows. You find the full line, change the Deployment so that all replicas fit, and leave the quota as it is.

Pause the playground first:

```sh
astrona stop ats-017-playground-050-01
```

Start the mission and send it for grading:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/labs/lab-01
astrona submit -c sections/section-050/module-01/labs/lab-01
```

When you finish, remove the mission cluster and resume the playground:

```sh
astrona destroy ats-017-lab-050-01-01
astrona start ats-017-playground-050-01
```
