---
estimated_duration: 30m
---

# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```bash
astrona submit --watch -c sections/section-010/capstone/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Read the starting state

```bash
kubectl -n starfleet get pods -o wide
kubectl -n outpost describe pod -l app=probe | grep -A3 "Events"
kubectl get nodes --show-labels | grep -o 'disktype=[a-z]*\|topology.kubernetes.io/zone=[a-z-]*'
```

All `scout` pods are on the `zone-a` node. The `probe` event says no node matched the node affinity, because no node has `disktype=nvme`.

## Step 2: Fix scout

Remove the `nodeSelector`, give every container the same request and limit, and add the topology spread constraint:

```bash
kubectl -n starfleet patch deployment scout --type=json -p='[
  {"op":"remove","path":"/spec/template/spec/nodeSelector"},
  {"op":"add","path":"/spec/template/spec/containers/0/resources","value":{
    "requests":{"cpu":"100m","memory":"64Mi"},
    "limits":{"cpu":"100m","memory":"64Mi"}}},
  {"op":"add","path":"/spec/template/spec/topologySpreadConstraints","value":[{
    "maxSkew":1,"topologyKey":"topology.kubernetes.io/zone",
    "whenUnsatisfiable":"DoNotSchedule",
    "labelSelector":{"matchLabels":{"app":"scout"}}}]}
]'
kubectl -n starfleet rollout status deployment/scout
kubectl -n starfleet get pods -l app=scout -o wide
```

The `NODE` column can show an uneven result, for example one pod on one worker and three on the other. The scheduler applies a topology spread constraint only when it places a pod. During the rolling update, the old pods still count in the skew, so the new pods do not end up even. Recreate all pods so the scheduler places them together:

```bash
kubectl -n starfleet scale deployment/scout --replicas=0
kubectl -n starfleet wait --for=delete pod -l app=scout
kubectl -n starfleet scale deployment/scout --replicas=4
kubectl -n starfleet rollout status deployment/scout
```

## Step 3: Fix probe

Change the affinity value from `nvme` to `ssd`:

```bash
kubectl -n outpost patch deployment probe --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/affinity/nodeAffinity/requiredDuringSchedulingIgnoredDuringExecution/nodeSelectorTerms/0/matchExpressions/0/values","value":["ssd"]}
]'
kubectl -n outpost rollout status deployment/probe
```

## Step 4: Prove the result

```bash
kubectl -n starfleet get pods -l app=scout -o wide
kubectl -n starfleet get pods -l app=scout -o jsonpath='{range .items[*]}{.status.qosClass}{"\n"}{end}'
kubectl -n outpost get pods -o wide
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://scout:9898/healthz
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://probe.outpost:8080/status/200
```

Two `scout` pods show each worker in `NODE`, every QoS class is `Guaranteed`, both `probe` pods run on the `ssd` node and both requests return `200`.

## Step 5: Submit

Press Ctrl-C to stop the watch, then run the plain command once:

```bash
astrona submit -c sections/section-010/capstone/labs/lab-01
```
