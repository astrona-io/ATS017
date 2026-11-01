---
estimated_duration: 45m
---

# Networking And Storage Capstone

The `bridge` front end and the `scout` API in `starfleet` are open to every pod, `scout` has no persistent storage, and nothing routes outside requests to them.

In this capstone you expose both through a Gateway, close every other path with NetworkPolicies, keep DNS working, and give `scout` a claim on a `Retain` StorageClass.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-017-capstone-020
```
