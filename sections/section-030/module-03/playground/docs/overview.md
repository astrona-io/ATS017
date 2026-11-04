# Explore VPA Recommendations

The Vertical Pod Autoscaler (VPA) calculates resource recommendations from usage. This playground has Kubernetes 1.35.8, VPA 1.7.3 and metrics-server for usage measurements. The VPA components are installed as plumbing.

In `starfleet`, Deployment `scout` and StatefulSet `probe` each have one Pod. Both use podinfo 6.15.0 with requests of `500m` CPU and `512Mi` memory, and limits of `1` CPU and `1Gi` memory. No VerticalPodAutoscaler or HorizontalPodAutoscaler objects exist yet.

Inspect the starting state:

```sh
kubectl -n starfleet get deployments,statefulsets,pods
kubectl -n starfleet top pods --containers
```

Compare usage with each workload's template. Create recommendation-only policies, then try bounded creation-time policies. Wait for real recommendations before replacing Pods. Compare names, UIDs, admission annotations and requests after each replacement. The exercises use only `kubectl`; Helm handles controller installation during preparation.

The one-replica StatefulSet can be unavailable during replacement. This is a disposable practice environment.
