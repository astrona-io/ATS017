---
estimated_duration: 25m
---

# Limit Pipeline Storage With ResourceQuota

Inspect a reverted Git commit to find a pipeline namespace that must not
create PersistentVolumeClaims (PVCs), requests for persistent storage. Set a
zero-count ResourceQuota there, stop its storage consumer and remove its
existing claim. Limit the count and total requested storage in two other
namespaces.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/labs/lab-03
```

When you think you have finished, send it for grading:

```bash
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-050/module-01/labs/lab-03
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-lab-050-01-03
```

Bootstrap creates the repository at `/tmp/cnpe-pipeline-review` on the terminal
and replaces that folder each time the lab starts. It uses the terminal's `git`.
It builds Git 2.56.0 only when no working `git` exists; the build prerequisites
are listed in [prerequisites.md](prerequisites.md).

The three checks read live objects. They also create real temporary PVCs to
check admission, then remove only their own test claims. The two bounded
namespaces must have room for small claims before grading.

Author validation: built without booting on 2026-11-04. Cluster bootstrap,
reference solution and live admission checks have not been executed.
