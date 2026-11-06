# Question

Solve this question on: `terminal`

## Scenario

The `starfleet` tenant runs frontend `shuttle`, backend `probe`, and an
unrelated workload `drifter`. Each Deployment has a `client` container with
curl and a live metrics endpoint on Transmission Control Protocol (TCP) port 9898. `probe` also serves its backend
on TCP 8080, through Service `probe` on port 80.

The namespace `outpost` has label `purpose: monitoring`. Its `shuttle` is the
approved monitoring client; its `drifter` is not. Namespace `relay` has a
`shuttle` with the same Pod label, but no monitoring namespace label.
The existing `allow-monitoring` NetworkPolicy has an overly broad `from`
list. The default network plugin is kindnet and enforces NetworkPolicy.

## Tasks

1. **Isolate the tenant.** Create NetworkPolicy `default-deny` in
   `starfleet`, selecting every Pod for both ingress and egress, with no
   allow rules of its own. Keep all Deployments, containers, Services and
   labels unchanged. Change NetworkPolicies only in `starfleet`.
2. **Restore DNS.** Create `allow-dns` for every tenant Pod. Allow DNS
   (Domain Name System) egress only to Pods labelled `k8s-app: kube-dns`
   in `kube-system`, on port 53 over User Datagram Protocol (UDP) and TCP. Every tenant workload
   must resolve `probe.starfleet.svc.cluster.local`.
3. **Permit one application flow.** Allow `app: shuttle` Pods in
   `starfleet` to reach `app: probe` Pods in that namespace on TCP 8080.
   Support both the direct Pod address and Service `probe` on port 80.
   The frontend must not reach the backend metrics listener on TCP 9898.
   `starfleet/drifter`, `outpost/shuttle` and `relay/shuttle` must not reach
   the backend on TCP 8080.
4. **Repair monitoring access.** Replace the broad permission in
   `allow-monitoring`. Allow only Pods with `app: shuttle` in namespaces
   labelled `purpose: monitoring` to reach TCP 9898 on every tenant Pod.
   Require the namespace and Pod labels together. Keep `outpost/drifter`,
   `relay/shuttle` and the local frontend unable to reach other tenant
   Pods on TCP 9898. The monitoring client must not reach TCP 8080.
5. **Keep other flows closed.** Every tenant workload must remain unable
   to reach the live metrics listener on TCP 9898 of `outpost/shuttle`.
   Deny other new connections except DNS, the application flow and
   monitoring described above. Replies to allowed connections must work.
