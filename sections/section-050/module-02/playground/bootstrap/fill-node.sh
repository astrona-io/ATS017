#!/usr/bin/env bash
# Fill the node with a low-priority `probe` Deployment in outpost: three
# replicas that request almost all the CPU that is still free. A new pod
# that requests 300m then cannot fit without preemption. The size comes from
# the node, because it depends on the machine that runs kind.
set -euo pipefail

node=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
allocatable=$(kubectl get node "$node" -o jsonpath='{.status.allocatable.cpu}')
to_millicores() {
  case "$1" in
    *m) echo "${1%m}" ;;
    *) echo $(( $1 * 1000 )) ;;
  esac
}
allocatable_m=$(to_millicores "$allocatable")

# Sum the CPU requests of every pod that is on the node and not finished.
requested_m=0
for value in $(kubectl get pods -A --field-selector "spec.nodeName=${node},status.phase!=Succeeded,status.phase!=Failed" \
  -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.resources.requests.cpu}{"\n"}{end}{end}'); do
  requested_m=$(( requested_m + $(to_millicores "$value") ))
done

# Leave 150m free so that no 300m pod fits, and split the rest in three.
probe_m=$(( (allocatable_m - requested_m - 150) / 3 ))

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
  replicas: 3
  selector:
    matchLabels:
      app: probe
  template:
    metadata:
      labels:
        app: probe
    spec:
      containers:
        - name: probe
          image: mccutchen/go-httpbin:2.25.0
          resources:
            requests:
              cpu: ${probe_m}m
              memory: 32Mi
            limits:
              memory: 64Mi
YAML
kubectl -n outpost rollout status deploy/probe --timeout=180s
