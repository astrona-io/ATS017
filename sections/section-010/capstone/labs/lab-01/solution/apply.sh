#!/usr/bin/env bash
# Reference solution for ats-017-capstone-010. Applied only by `astrona test`.
set -euo pipefail

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
kubectl -n starfleet rollout status deployment/scout --timeout=240s
# The scheduler applies the constraint only when it places a pod, so the
# rolled-out pods can end uneven. Recreate all pods to place them together.
kubectl -n starfleet scale deployment/scout --replicas=0
kubectl -n starfleet wait --for=delete pod -l app=scout --timeout=120s
kubectl -n starfleet scale deployment/scout --replicas=4
kubectl -n starfleet rollout status deployment/scout --timeout=240s

kubectl -n outpost patch deployment probe --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/affinity/nodeAffinity/requiredDuringSchedulingIgnoredDuringExecution/nodeSelectorTerms/0/matchExpressions/0/values","value":["ssd"]}
]'
kubectl -n outpost rollout status deployment/probe --timeout=180s
