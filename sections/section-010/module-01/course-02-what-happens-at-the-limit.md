# What Happens At The Limit

A limit is not a warning. When a container reaches it, the Linux kernel acts at once, and it acts very differently for CPU and for memory. One container keeps running, only slower; the other is killed and restarted. This part pushes one `podinfo` container past its CPU limit and another past its memory limit, so you can recognise both results on sight.

## CPU is compressible

CPU time can be handed out in smaller slices without breaking a program, so Kubernetes calls CPU a **compressible** resource. When a container wants more CPU than its limit, the kernel simply stops running it for the rest of each 100 millisecond period. This is called **CPU throttling**. The container stays up; it just gets slower.

The `--stress-cpu=1` flag makes `podinfo` keep one full core busy. Give it a limit of `200m` and watch what it gets.

<!-- astrona:playground:renew -->

Save this as `deployment-scout-cpu-hog.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout-cpu-hog
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scout-cpu-hog
  template:
    metadata:
      labels:
        app: scout-cpu-hog
    spec:
      containers:
        - name: scout
          image: ghcr.io/stefanprodan/podinfo:6.15.0
          args: ["./podinfo", "--stress-cpu=1"]
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
```

Apply it:

```sh
kubectl apply -f deployment-scout-cpu-hog.yaml
```

Wait about a minute, because metrics-server needs a few samples before it reports a new pod. Then check the usage:

```sh
kubectl top pods -n starfleet
```

You should see something like:

```text
NAME                                CPU(cores)   MEMORY(bytes)   
scout-besteffort-74b446bc89-hhqsv   0m           13Mi            
scout-burstable-67658c66f7-rrrft    1m           12Mi            
scout-cpu-hog-6fc66bc6d6-pmttf      200m         12Mi            
scout-guaranteed-5dd68c8779-9qhmx   0m           12Mi            
shuttle-5c44b786bb-cd2sf            0m           0Mi
```

The container wants a full core (`1000m`), but it uses exactly `200m`, its limit. It shows no error and no restart. That flat line at the limit is the signature of throttling: usage that never goes above the limit, while the application is slower than it should be.

The kernel keeps counters for this in the container's cgroup. `cpu.max` holds the limit as "quota per period" in microseconds, and `cpu.stat` counts how often the quota ran out:

```sh
kubectl -n starfleet exec deploy/scout-cpu-hog -- cat /sys/fs/cgroup/cpu.max /sys/fs/cgroup/cpu.stat
```

You should see something like:

```text
20000 100000
usage_usec 10336133
user_usec 10271005
system_usec 65127
nice_usec 0
core_sched.force_idle_usec 0
nr_periods 516
nr_throttled 516
throttled_usec 32129294
nr_bursts 0
burst_usec 0
```

`20000 100000` is the `200m` limit: 20,000 microseconds of CPU time in every 100,000 microsecond period. `nr_throttled` equals `nr_periods`, so the container ran out of CPU time in every single period, and `throttled_usec` is the total time it spent waiting. On a real service, rising `nr_throttled` with slow responses means the CPU limit is too low.

## Memory is not compressible

Memory cannot be taken back from a program without breaking it, so memory is **incompressible**. When a container's memory use reaches its limit, the kernel's out-of-memory killer ends the process. Kubernetes reports this as the reason **`OOMKilled`**, and the kubelet restarts the container according to the pod's `restartPolicy`.

The `--stress-memory=300` flag makes `podinfo` load 300 MB of data into memory, more than a `128Mi` limit allows.

Save this as `deployment-scout-memory-hog.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout-memory-hog
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scout-memory-hog
  template:
    metadata:
      labels:
        app: scout-memory-hog
    spec:
      containers:
        - name: scout
          image: ghcr.io/stefanprodan/podinfo:6.15.0
          args: ["./podinfo", "--stress-memory=300"]
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
```

Apply it, wait about a minute, and look at the pod:

```sh
kubectl apply -f deployment-scout-memory-hog.yaml
kubectl -n starfleet get pods -l app=scout-memory-hog
```

You should see something like:

```text
NAME                                READY   STATUS      RESTARTS      AGE
scout-memory-hog-7c87554bc4-lskv9   0/1     OOMKilled   2 (51s ago)   79s
```

Depending on the moment you look, the `STATUS` column shows `Running`, `OOMKilled` or `CrashLoopBackOff`. `CrashLoopBackOff` means the kubelet waits longer before each new restart. The `RESTARTS` count keeps growing in all three cases. The reason for the last restart is stored in the container status:

```sh
kubectl -n starfleet describe pod -l app=scout-memory-hog | sed -n '/^    State:/,/Restart Count/p'
```

You should see something like:

```text
    State:          Running
      Started:      Sat, 10 Oct 2026 16:54:26 +0200
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
      Started:      Sat, 10 Oct 2026 16:54:01 +0200
      Finished:     Sat, 10 Oct 2026 16:54:14 +0200
    Ready:          True
    Restart Count:  2
```

`Last State` is the proof: `Terminated` with `Reason: OOMKilled` and `Exit Code: 137`. Exit code 137 is 128 plus 9, the number of the `SIGKILL` signal, so the process was killed and had no chance to clean up. The current `State` is `Running` because the kubelet already started it again; it will be killed again as soon as it fills its memory. The same fields are in `status.containerStatuses[].lastState.terminated` in the pod's YAML.

## Telling the two apart

Both problems make an application look unhealthy, but the evidence is different, and so is the fix:

| Signal | CPU over its limit | Memory over its limit |
| --- | --- | --- |
| Pod status | `Running`, no restarts | Restarts, `OOMKilled`, then `CrashLoopBackOff` |
| `kubectl top` | Flat at the limit | Climbs to the limit, then drops after each restart |
| Where to look | `cpu.stat` (`nr_throttled`), slow responses | `Last State` reason `OOMKilled`, exit code `137` |
| Usual fix | Raise or remove the CPU limit | Raise the memory limit, or reduce the application's memory use |

A node can also kill containers for memory without any limit being reached, when the whole node runs short. That case is called eviction, and the next part covers it.

You can now tell a throttled container from an `OOMKilled` one by its status, its restart count and its counters. The open question is what Kubernetes does when no single container is over its limit but the node as a whole runs out of memory: which pods go first.

## Common pitfalls

> [!WARNING]
> - **Looking for an error when CPU is the problem.** Throttling produces no event and no restart. Check `kubectl top` against the limit and `nr_throttled`.
> - **Reading only the current `State`.** After a restart it says `Running`. The reason is in `Last State`.
> - **Deleting the pod to "fix" an `OOMKilled` container.** The new pod has the same limit and is killed again. Change the limit or the application.
> - **Setting a memory limit far above the request on many pods.** Each pod looks fine alone, but together they can use more memory than the node has.
