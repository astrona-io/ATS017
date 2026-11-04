# Summary

The Vertical Pod Autoscaler (VPA) calculates container resource requests from measured usage. A VerticalPodAutoscaler targets a workload controller such as a Deployment or StatefulSet. Its status holds the recommendation; a short sample window is useful for practice but does not establish a production peak.

Container policies bound recommended requests with minAllowed and maxAllowed. RequestsOnly keeps limits separate. Off leaves recommendations as advice. Initial lets admission apply them when a Pod is created, so replacing a Pod gives it a new UID and potentially new requests while its workload template stays unchanged.

Recreate allows replacement, and the in-place modes use Kubernetes resize support with different eviction rules. Auto is deprecated. Supporting in-place resize does not change the meaning of Initial.

A Horizontal Pod Autoscaler changes replica count. Keep its resource utilisation calculation stable by avoiding automatic VPA updates to the same CPU or memory requests. Use separate workloads, fixed requests with VPA Off, or deliberately separate metrics and resource ownership.

<!-- astrona:playground:destroy -->
