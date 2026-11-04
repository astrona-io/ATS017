# Prerequisites

- Use `kubectl get`, `kubectl describe`, `kubectl apply` and `kubectl scale`.
- Know that a PersistentVolumeClaim (PVC) requests storage, and a pod can
  mount that claim as a volume.
- Know that a ResourceQuota limits the total resources in one namespace.
- Read a Git patch: lines starting with `+` are additions and lines starting
  with `-` are removals. A revert undoes a commit in a new commit.

The cluster is a single-node kind cluster on Kubernetes 1.35.8. Astrona sets
`KUBECONFIG` for the terminal. Each pipeline namespace starts with one `1Gi`
claim and a Deployment running go-httpbin 2.25.0 that mounts it.

The terminal needs `git`. The lab uses it only to read local history, so any
current release works. If no working `git` exists, bootstrap builds Git 2.56.0
in `~/.local/ats017-git-2.56.0` and links it next to `kubectl`. That build needs
network access, a C compiler, `make`, Perl, zlib development headers, `curl` and
`tar`, and it can take several minutes. Installing Git from your package manager
before the lab avoids the build.
