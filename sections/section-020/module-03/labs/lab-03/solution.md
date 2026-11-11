# Solution Walkthrough

Inspect the two distinct claim identities and the policy that controls their deletion:

```sh
kubectl -n starfleet get sts probe -o yaml
kubectl -n starfleet get pvc data-probe-0 data-probe-1 -o yaml
kubectl -n starfleet exec probe-0 -- cat /data/record
kubectl -n starfleet exec probe-1 -- cat /data/record
```

Set both controller retention decisions explicitly:

```sh
kubectl -n starfleet patch statefulset probe --type=merge -p '{"spec":{"persistentVolumeClaimRetentionPolicy":{"whenScaled":"Retain","whenDeleted":"Retain"}}}'
kubectl -n starfleet get pvc data-probe-0 data-probe-1 -o yaml
```

Wait for the StatefulSet controller to remove the claims' owner references. Then exercise the lifecycle:

```sh
kubectl -n starfleet scale statefulset probe --replicas=1
kubectl -n starfleet wait --for=delete pod/probe-1 --timeout=120s
kubectl -n starfleet get pvc data-probe-0 data-probe-1
kubectl -n starfleet scale statefulset probe --replicas=2
kubectl -n starfleet rollout status statefulset/probe --timeout=180s
kubectl -n starfleet delete pod probe-0
kubectl -n starfleet rollout status statefulset/probe --timeout=180s
kubectl -n starfleet exec probe-0 -- cat /data/record
kubectl -n starfleet exec probe-1 -- cat /data/record
```

Both claims keep their UIDs and bound volumes. Both records survive. Retaining a PV after claim deletion would leave a Released volume requiring recovery; retaining the claims lets the StatefulSet reuse them directly.
