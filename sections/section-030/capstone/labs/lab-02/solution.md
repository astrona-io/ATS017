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
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/capstone/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

The `policies` and `applied` checks need your changes and should fail in the untouched environment. The `sizing` and `hpa` checks also need changes; `hpa` generates its own temporary CPU load and can take several minutes.

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
    updateMode: 'Off'
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

This object selects Deployment `scout` and its `scout` container. Its `Off` mode keeps recommendations as advice so the HPA will use fixed requests. The resource policy has the same bounds and preserves limits.

Then check the result:

```sh
kubectl -n starfleet wait --for=condition=RecommendationProvided vpa/probe --timeout=600s
kubectl -n starfleet wait --for=condition=RecommendationProvided vpa/scout --timeout=600s
kubectl -n starfleet get vpa probe scout -o yaml
```

Look under `status.recommendation.containerRecommendations` for each named container's bounded target. Do not replace Pods until these recommendations exist.

The watch terminal now shows `policies` passing.

## Step 3: Replace Pods after the recommendation

Replace the StatefulSet Pod. A new Pod keeps the name `probe-0` but gets a new UID. This briefly interrupts the one-replica workload.

```sh
kubectl -n starfleet delete pod probe-0
kubectl -n starfleet rollout status statefulset/probe --timeout=180s
kubectl -n starfleet get pod probe-0 -o yaml
```

Look for a new UID, a Ready container and `vpaUpdates` naming `probe`. Check that both requests fall inside the policy. Compare the Pod's requests with `status.containerStatuses[0].resources.requests`. Limits must remain unchanged.

The watch terminal now shows `applied` passing.

## Step 4: Reduce the Deployment template requests

Read live usage and the recommendation before applying the team's fixed budget. The **request** is the amount reserved on a node; the **limit** caps use. VPA stays `Off` on this workload, so only your template edit sets requests for new replicas.

```sh
kubectl -n starfleet top pods --containers
kubectl -n starfleet get vpa scout -o yaml
kubectl -n starfleet set resources deployment/scout --requests=cpu=100m,memory=256Mi
kubectl -n starfleet rollout status deployment/scout --timeout=180s
kubectl -n starfleet get pods -l app=scout -o yaml
```

Compare measured memory with `256Mi` and confirm that the new Pods use the budget. The command changes only requests and leaves the original limits. CPU usage under the later load can exceed the CPU request; a request is not a CPU limit. This practice budget is not a production sizing conclusion.

The watch terminal now shows `sizing` passing.

## Step 5: Add the HPA and generate load

A **Horizontal Pod Autoscaler (HPA)** changes replica count from metrics. Save this as `hpa-scout.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: scout
  namespace: starfleet
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scout
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
```

Apply it:

```sh
kubectl apply -f hpa-scout.yaml
```

`scaleTargetRef` selects the Deployment. The bounds allow one to three replicas. `Resource` selects container resource usage; `Utilization` divides CPU usage by requests and compares it with 60 percent. The scale-down window retains recent higher replica recommendations for 60 seconds. It is not a fixed delay from when your load command ends.

Then check the result:

```sh
kubectl -n starfleet describe hpa scout
```

Wait for a resolved CPU target and `ScalingActive: True`. Generate temporary load from the client. Curl's numeric URL range repeats POST requests to podinfo's token-generation endpoint; the query number only varies the URL. Each worker stops after 170 seconds.

```sh
kubectl -n starfleet exec deploy/shuttle -- sh -c 'for worker in 1 2 3 4; do timeout 170 curl -s -o /dev/null -X POST "http://scout/token?[1-5000000]" & done; wait'
```

While that command runs, use another terminal to observe scaling:

```sh
kubectl -n starfleet get hpa scout --watch
```

Look for CPU utilisation above 60 percent and a replica count above one. End the watch with Ctrl+C. Read Ready replicas with `kubectl -n starfleet get deployment scout`. Keep VPA `scout` in `Off`: enabling resource updates would change the denominator HPA uses. The watch terminal shows `hpa` passing once the grader's own fresh load leaves at least two replicas Ready.

## Submit

After all checks pass, press Ctrl-C to stop the watch, then run the plain command once from the host terminal:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/capstone/labs/lab-02
```

## If a check stays red

- **`policies` fails:** check controller kind, name and namespace, then each named container policy. Use explicit update modes and wait for both recommendations. If `kubectl top` fails, inspect the usage metrics plumbing.
- **`applied` fails:** a container restart is not a new Pod. Replace the Pod after recommendations exist, check the UID and admission annotation, and wait for readiness. Do not edit the workload template to imitate VPA admission.
- **`sizing` fails:** change the Deployment template, wait for its rollout and for new usage samples, and keep VPA `Off`. If memory usage exceeds the budget, inspect the process and workload state before proceeding.
- **`hpa` fails:** inspect the HPA conditions, CPU requests, replica bounds and scale-down window. Keep `shuttle` Ready and confirm that the `scout` Service selects Ready Pods. The check needs real metrics and enough node capacity for two replicas.
