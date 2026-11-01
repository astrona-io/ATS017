#!/usr/bin/env bash
# Reference solution for ats-017-lab-010-02-01. Applied only by `astrona test`.
set -euo pipefail

kubectl -n outpost patch deployment probe --type=json -p='[
  {"op":"add","path":"/spec/template/spec/tolerations","value":[
    {"key":"dedicated","operator":"Equal","value":"outpost","effect":"NoSchedule"}]}
]'
kubectl -n outpost rollout status deployment/probe --timeout=180s
