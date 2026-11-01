---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

The `scout` service in the namespace `starfleet` must keep files in `/data` when its pod is replaced. The `scout` Deployment already mounts the PersistentVolumeClaim `scout-data` at `/data`, but its pod stays `Pending` and the claim never binds.

The namespace also has a `shuttle` Deployment, a client pod with `curl`. The StorageClass `standard` is the cluster default.

Find out why the claim does not bind, and fix it so that:

1.  The claim `scout-data` is `Bound` and still uses the StorageClass `standard`.
2.  The `scout` Deployment is ready and mounts `scout-data` at `/data`.
3.  A file written to `/data` is still there after the `scout` pod is deleted and the Deployment starts a new one.

Constraints:

* Keep the names `scout`, `scout-data` and `standard`.
* Do not replace the claim with an `emptyDir` or a `hostPath` volume.
* Do not create a new StorageClass.

The grader checks the claim, the Deployment and its volume mount. Then it writes a file in `/data`, deletes the running `scout` pod, waits for the replacement pod and reads the file again.
