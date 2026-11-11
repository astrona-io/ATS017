# Solution Walkthrough

Inspect the assigned workload and its current measurements:

```sh
kubectl -n starfleet describe pod -l app=scout-overprovisioned
kubectl -n starfleet get deployment scout-overprovisioned -o yaml
kubectl -n starfleet top pod -l app=scout-overprovisioned
```

A repeatedly killed container may not live long enough to yield metrics. In that case, use the known stress allocation to choose an initial ceiling, then measure after the rollout. For this fixture, the reference values are:

```sh
kubectl -n starfleet set resources deployment/scout-overprovisioned --requests=cpu=20m,memory=64Mi --limits=memory=128Mi
kubectl -n starfleet rollout status deployment/scout-overprovisioned --timeout=180s
kubectl -n starfleet top pod -l app=scout-overprovisioned
kubectl -n starfleet get pods -l app=scout-overprovisioned -o wide
```

Wait for metrics for the new Pod rather than reading a terminating Pod. Confirm that its memory request covers measured usage and that it stays Ready without another restart. The supplied values fit this steady lab workload; production sizing needs representative peak measurements and application latency checks.
