---
estimated_duration: 45m
---

# Question

Solve this question on: `terminal`

The namespace `starfleet` runs `bridge` (an nginx front end on Service port `80`), `scout` (an HTTP API on Service port `80`, container port `9898`) and `shuttle`, a client pod with `curl`. The namespace `outpost` has its own `shuttle`. No Gateway, route, NetworkPolicy or claim exists yet, and every pod can reach every other pod.

The GatewayClass is `eg`. The controller runs the Gateway's proxy pods in a different namespace; find it with `kubectl get pods -A`.

Make these four things true:

1.  **Gateway and route.** A Gateway named `starfleet-gateway` in `starfleet` accepts HTTP on port `80`. Requests with a path starting with `/api` go to `scout`. Every other path goes to `bridge`.
2.  **Isolation.** Pods in `starfleet` accept incoming traffic only from the Gateway's proxy pods. Every other incoming and outgoing flow in `starfleet` is denied.
3.  **DNS.** Pods in `starfleet` can still resolve names through the cluster DNS service.
4.  **Storage.** `scout` keeps files in `/data` on a PersistentVolumeClaim named `scout-data` that uses the StorageClass `standard-retain`. The volume must survive deleting the claim.

Constraints:

* Do not delete `bridge`, `scout`, their Services or either `shuttle`.
* Do not use `emptyDir` or `hostPath` for `/data`.
* Do not open the isolation with an allow-all rule.

The grader sends requests from the `shuttle` in `outpost` to the Gateway address. `GET /api/info` must return the answer of `scout` and `GET /` must return the page of `bridge`. Requests from `outpost` straight to the `scout` and `bridge` Services must time out. A DNS lookup must work from the `shuttle` in `starfleet`. Last, the grader writes a file to `/data`, deletes the `scout` pod and reads the file from the new pod.
