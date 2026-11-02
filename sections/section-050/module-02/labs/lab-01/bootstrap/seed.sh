#!/usr/bin/env bash
# Creates the starting state for ats-017-lab-050-02-01.
# astrona runs this script with KUBECONFIG pointed at the lab cluster.
# The outpost probe Deployment (three replicas, no PriorityClass) requests
# almost all the free CPU of the node. starfleet/scout-critical requests 300m
# and stays Pending. The size of probe depends on the node, so it is
# computed here and recorded in an annotation for the grader.
set -euo pipefail

kubectl create namespace starfleet --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace outpost --dry-run=client -o yaml | kubectl apply -f -

node=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
allocatable=$(kubectl get node "$node" -o jsonpath='{.status.allocatable.cpu}')
to_millicores() {
  case "$1" in
    *m) echo "${1%m}" ;;
    *) echo $(( $1 * 1000 )) ;;
  esac
}
allocatable_m=$(to_millicores "$allocatable")

requested_m=0
for value in $(kubectl get pods -A --field-selector "spec.nodeName=${node},status.phase!=Succeeded,status.phase!=Failed" \
  -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.resources.requests.cpu}{"\n"}{end}{end}'); do
  requested_m=$(( requested_m + $(to_millicores "$value") ))
done

probe_m=$(( (allocatable_m - requested_m - 150) / 3 ))

echo "==> outpost/probe: 3 replicas of ${probe_m}m"
kubectl apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: outpost
  labels:
    app: probe
  annotations:
    lab/probe-cpu: "${probe_m}m"
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
kubectl -n outpost rollout status deploy/probe --timeout=240s

echo "==> starfleet/scout-critical (300m CPU, no PriorityClass)"
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout-critical
  namespace: starfleet
  labels:
    app: scout-critical
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: scout-critical
  template:
    metadata:
      labels:
        app: scout-critical
    spec:
      containers:
        - name: scout
          image: ghcr.io/stefanprodan/podinfo:6.15.0
          resources:
            requests:
              cpu: 300m
              memory: 32Mi
            limits:
              memory: 64Mi
YAML

echo "==> Waiting for the scheduler to report Pending"
for _ in $(seq 1 30); do
  phase=$(kubectl -n starfleet get pods -l app=scout-critical -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
  [ "$phase" = "Pending" ] && break
  sleep 2
done
kubectl -n starfleet get pods -l app=scout-critical

echo "==> Lab ats-017-lab-050-02-01 ready."
