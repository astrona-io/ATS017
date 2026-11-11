# Solution Walkthrough

Use the terminal to create Vertical Pod Autoscaler (VPA) objects and replace Pods after recommendations appear. VPA calculates resource requests; its admission controller applies permitted changes when a Pod is created.

| Goal | Where it lives | How to inspect it |
| --- | --- | --- |
| Select the workload | `spec.targetRef` | `kubectl get vpa -o yaml` |
| Bound requests | `spec.resourcePolicy.containerPolicies` | Read the minimum, maximum and controlled values |
| Read the estimate | `status.recommendation` | Match the container name |
| Prove the applied request | Pod specification and container status | Compare requests, readiness and UID |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/module-03/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

The `policies` and `applied` checks need your changes and should fail in the untouched environment. There is no sample grading output because this lab was built without booting.

## Step 1: Inspect the starting state

Read the existing workload templates and the Pod identities. A unique identifier (UID) distinguishes a replacement Pod from its predecessor.

```sh
kubectl -n starfleet get deployment scout -o yaml
kubectl -n starfleet get statefulset probe -o yaml
kubectl -n starfleet get pods -o yaml
kubectl -n starfleet top pods --containers
```

Look for requests of `500m` CPU and `512Mi` memory. Record the Pod UIDs in your notes. No check changes yet.

## Step 2: Create both VPA objects

Save this as `vpa-probe.yaml`:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: probe
  namespace: starfleet
spec:
  targetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: probe
  updatePolicy:
    updateMode: Initial
  resourcePolicy:
    containerPolicies:
    - containerName: probe
      controlledResources:
      - cpu
      - memory
      controlledValues: RequestsOnly
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: 300m
        memory: 256Mi
```

Apply it:

```sh
kubectl apply -f vpa-probe.yaml
```

`apiVersion` and `kind` select the VPA API. `metadata` names the object and namespace. `targetRef` selects StatefulSet `probe`. `Initial` allows changes only at creation. `containerName` names the application container; `controlledResources` selects CPU and memory. `RequestsOnly` preserves limits, while `minAllowed` and `maxAllowed` bound recommended requests.

Save this as `vpa-scout.yaml`:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: scout
  namespace: starfleet
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scout
  updatePolicy:
    updateMode: Initial
  resourcePolicy:
    containerPolicies:
    - containerName: scout
      controlledResources:
      - cpu
      - memory
      controlledValues: RequestsOnly
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: 300m
        memory: 256Mi
```

Apply it:

```sh
kubectl apply -f vpa-scout.yaml
```

This object selects Deployment `scout` and its `scout` container. Its `Initial` mode allows the same creation-time updates as the StatefulSet policy. The resource policy has the same bounds and preserves limits.

Then check the result:

```sh
kubectl -n starfleet wait --for=condition=RecommendationProvided vpa/probe --timeout=600s
kubectl -n starfleet wait --for=condition=RecommendationProvided vpa/scout --timeout=600s
kubectl -n starfleet get vpa probe scout -o yaml
```

Look under `status.recommendation.containerRecommendations` for each named container's bounded target. Do not replace Pods until these recommendations exist. The watch terminal now shows `policies` passing.

## Step 3: Replace Pods after the recommendation

Replace the StatefulSet Pod. A new Pod keeps the name `probe-0` but gets a new UID. This briefly interrupts the one-replica workload.

```sh
kubectl -n starfleet delete pod probe-0
kubectl -n starfleet rollout status statefulset/probe --timeout=180s
kubectl -n starfleet get pod probe-0 -o yaml
```

Look for a new UID, a Ready container and `vpaUpdates` naming `probe`. Check that both requests fall inside the policy. Compare the Pod's requests with `status.containerStatuses[0].resources.requests`. Limits must remain unchanged.

Replace the Deployment's Pod through its existing ReplicaSet. A rollout restart creates a new ReplicaSet, which the VPA admission controller may not have discovered when the first Pod arrives. Deleting this single practice Pod briefly interrupts the workload:

```sh
kubectl -n starfleet delete pod -l app=scout
kubectl -n starfleet rollout status deployment/scout --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod -l app=scout --timeout=180s
kubectl -n starfleet get pods -l app=scout -o yaml
kubectl -n starfleet get deployment scout -o yaml
```

Look for a replacement UID and the same admission and readiness evidence. The Deployment template still requests `500m` CPU and `512Mi` memory. The Pod requests come from VPA admission, not a template edit.

The watch terminal now shows `applied` passing.

## Submit

After all checks pass, press Ctrl-C to stop the watch, then run the plain command once from the host terminal:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/module-03/labs/lab-01
```

## If a check stays red

- **`policies` fails:** check controller kind, name and namespace, then each named container policy. Use explicit update modes and wait for both recommendations. If `kubectl top` fails, inspect the usage metrics plumbing.
- **`applied` fails:** a container restart is not a new Pod. Replace the Pod after recommendations exist, check the UID and admission annotation, and wait for readiness. Do not edit the workload template to imitate VPA admission.
