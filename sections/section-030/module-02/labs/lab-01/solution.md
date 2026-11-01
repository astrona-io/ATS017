---
estimated_duration: 25m
---

# Solution

## Step 1: Read the current resources and the events

Print the requests and limits of both pods, then find out why `scout-underprovisioned` restarts:

```bash
kubectl -n starfleet get pods -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,MEM_LIM:.spec.containers[0].resources.limits.memory,RESTARTS:.status.containerStatuses[0].restartCount'
kubectl -n starfleet describe pod -l app=scout-underprovisioned | grep -A3 'Last State'
```

`scout-overprovisioned` requests `1` CPU and `1Gi` of memory. `scout-underprovisioned` has a memory limit of `64Mi` and a growing restart count. In `describe`, the last state of its container is `Terminated` with the reason `OOMKilled`. The kernel killed the container because it used more memory than its limit.

## Step 2: Measure the usage

Read the usage of both containers:

```bash
kubectl -n starfleet top pods --containers
```

`scout-overprovisioned` uses a few millicores of CPU and a few tens of mebibytes of memory. `scout-underprovisioned` uses about `110Mi`: podinfo itself, plus the 100 megabytes that `--stress-memory=100` holds. The `top` value of `scout-underprovisioned` can be low or missing for a short time after a restart, so repeat the command until it shows a stable value.

## Step 3: Set new values in the Deployments

The checks accept a range, so any reasonable value works. For `scout-overprovisioned`, a CPU request of `20m` and a memory request of `32Mi` cover the usage with headroom. A memory limit of `64Mi` keeps a ceiling. For `scout-underprovisioned`, a memory request and limit of `160Mi` cover about `110Mi` of usage with headroom:

```bash
kubectl -n starfleet set resources deployment/scout-overprovisioned \
  --requests=cpu=20m,memory=32Mi --limits=memory=64Mi
kubectl -n starfleet set resources deployment/scout-underprovisioned \
  --requests=cpu=20m,memory=160Mi --limits=memory=160Mi
```

Both commands change the Deployment templates, so each Deployment starts a new pod. Wait for the rollouts:

```bash
kubectl -n starfleet rollout status deployment/scout-overprovisioned
kubectl -n starfleet rollout status deployment/scout-underprovisioned
```

## Step 4: Check the result

Print the resources and the restart counts again, and wait a minute:

```bash
kubectl -n starfleet get pods -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,MEM_LIM:.spec.containers[0].resources.limits.memory,RESTARTS:.status.containerStatuses[0].restartCount'
```

Both pods are `Running`, and `scout-underprovisioned` shows `0` restarts that keep at `0`. Submit the lab:

```bash
astrona submit -c sections/section-030/module-02/labs/lab-01
```

The grader reads the Deployments and checks the ranges from the task. It reads the memory that `scout-underprovisioned` uses from `kubectl top`, and it requires a request and a limit at or above that usage. It also checks that the images and arguments are unchanged, that both pods are `Ready`, and that the container does not restart during 30 seconds. A reference run printed:

```text
OK: scout-overprovisioned requests 20m CPU and 32Mi memory, limit 64Mi
OK: scout-underprovisioned requests 160Mi of memory (usage about 109Mi), limit 160Mi
OK: arguments and images are unchanged
OK: both pods are Ready and scout-underprovisioned is not restarted
```

## Why other fixes fail

Raising only the memory limit of `scout-underprovisioned` and leaving the request at `16Mi` ends the kills, but the request stays below the usage, and the grader rejects it. Removing the memory limits is also rejected, because the task says to keep them. Resizing the running pods in place does not pass, because the grader reads the Deployments, and the next pod would start with the old values.
