#!/usr/bin/env bash
# Fill both workers with one low-priority `probe` replica each, sized so that
# almost no CPU is left to request on either worker. A new pod that requests
# real CPU then cannot fit without preemption. The size is computed from the
# worker's allocatable CPU, because it depends on the machine running kind.
set -euo pipefail

worker=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
allocatable=$(kubectl get node "$worker" -o jsonpath='{.status.allocatable.cpu}')
case "$allocatable" in
  *m) allocatable_millicores=${allocatable%m} ;;
  *)  allocatable_millicores=$((allocatable * 1000)) ;;
esac
# Leave 300m for the node's own pods (kindnet and kube-proxy request 100m).
probe_request=$((allocatable_millicores - 300))

# bootstrap init steps may run before the manifests, so make sure the
# namespace exists here.
kubectl create namespace outpost --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: outpost
  labels:
    app: probe
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probe
  template:
    metadata:
      labels:
        app: probe
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: probe
      containers:
        - name: probe
          image: mccutchen/go-httpbin:2.25.0
          resources:
            requests:
              cpu: ${probe_request}m
              memory: 32Mi
            limits:
              memory: 64Mi
YAML
kubectl -n outpost rollout status deploy/probe --timeout=180s
