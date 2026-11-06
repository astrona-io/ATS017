# Question

Solve this question on: `terminal`

## Scenario

The `outpost` team has an HTTPRoute, but its application is not serving
through the shared Gateway. The Gateway `starfleet-gateway` is in
`starfleet`, with one HTTP listener named `http` on port 80. It currently
allows routes only from its own namespace. The team's `team-route` in
`outpost` also names listener `web`, which does not exist.

Services `bridge`, `scout` and `probe` in `outpost` listen on Service port
80. `bridge` returns `outpost front end`, `scout` serves `/api/info`, and
`probe` echoes headers at `/headers`. A separate `bridge` in `starfleet`
returns `starfleet front end`. The `relay` route in `outpost` already
references that cross-namespace backend, but no ReferenceGrant permits it.

## Tasks

1. **Repair attachment.** Allow HTTPRoutes from `outpost` on listener `http`
   and change `team-route` to select it. Keep the Gateway in `starfleet`
   and both routes in `outpost`. Both routes must report fresh
   `Accepted=True` and `ResolvedRefs=True` for this parent by the end.
   Keep `team.starfleet.example` as `team-route`'s hostname and send its
   default `/` request to `outpost/bridge` on port 80.
2. **Route a path prefix.** Add a `PathPrefix` rule for `/api` to `team-route`
   that forwards to `outpost/scout` on port 80. `/api/info` must return a
   live `scout` pod's hostname.
3. **Route a canary header.** Add an exact header match for `x-version:
   canary` with path prefix `/` that forwards to `outpost/probe` on port
   80. `/headers` with that header must return the echoed header. Without
   the header, `/` must still reach `bridge`. `/api/info` must still reach
   `scout` even when the canary header is present.
4. **Permit the cross-namespace backend.** Create a ReferenceGrant in
   `starfleet` that allows HTTPRoutes from `outpost` to reference Service
   `bridge`. Keep `relay.starfleet.example` as `relay`'s hostname and its
   backend `starfleet/bridge` on port 80. A request to `/` through this
   route must return `starfleet front end`.

Use the existing Gateway and routes. Keep the Gateway listener's name,
protocol and port. Keep all workloads, Service selectors, images and
response bodies unchanged. Send requests from `starfleet`'s `shuttle` to
the Gateway address in `status.addresses`, with the required Host header.
