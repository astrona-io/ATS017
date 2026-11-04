# Prerequisites

Know how to inspect Pods, Deployments and StatefulSets with kubectl. Understand resource requests, limits, CPU millicores and memory units. Be able to apply a YAML manifest and wait for a rollout.

The Vertical Pod Autoscaler (VPA) recommends container resource requests. The environment already has VPA 1.7.3, Kubernetes 1.35.8 and metrics-server. You create the autoscaler objects, not the controller installation. The terminal needs kubectl; preparation needs Helm 4.x, and the live-state grader needs Python 3.

Read a VPA recommendation before replacing a Pod. A one-replica StatefulSet can be briefly unavailable during replacement. The environment is disposable.
