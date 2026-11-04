# Install OpenCost And Check Its Data Sources

OpenCost shows a cost of zero when one of its inputs is missing, and it does not print an error. A new installation often fails this way: the pods are `Running`, the API answers with `200`, and every number is `0`. To fix a silent zero, you need to know what OpenCost depends on and how to check each dependency.

OpenCost has two dependencies. It needs a Prometheus that holds the usage and request metrics, and it needs a price list. This part shows what the Helm installation contains, how to prove that Prometheus scrapes the right targets, and how to prove that OpenCost loaded its prices.

## See what the playground installed

The playground start-up script already installed both with Helm, so you can read the result instead of typing the install commands. Helm installs a chart, which is a package of Kubernetes manifests, as a named release. The command `helm list` shows the releases and their chart versions.

<!-- astrona:playground:renew -->

```sh
helm list -A
```

You should see something like:

```text
NAME      	NAMESPACE 	REVISION	UPDATED                             	STATUS  	CHART             	APP VERSION
opencost  	opencost  	1       	2026-11-01 22:58:30.363129 +0100 CET	deployed	opencost-2.5.33   	1.121.3    
prometheus	monitoring	1       	2026-11-01 22:57:50.272766 +0100 CET	deployed	prometheus-29.40.3	v3.15.1    
```

The `prometheus` release lives in the namespace `monitoring`. It runs the Prometheus server and kube-state-metrics, which is a pod that turns the objects in the Kubernetes API into metrics. The `opencost` release lives in the namespace `opencost`. It runs one pod with two containers: `opencost`, which computes the allocation, and `opencost-ui`, which serves a web page.

```sh
kubectl -n opencost get pods
kubectl -n opencost get svc
```

You should see something like:

```text
NAME                        READY   STATUS    RESTARTS   AGE
opencost-749d4c577f-49hnn   2/2     Running   0          97s

NAME       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)             AGE
opencost   ClusterIP   10.96.75.237   <none>        9003/TCP,9090/TCP   91s
```

The Service `opencost` exposes two ports. Port `9003` serves the allocation API, and port `9090` serves the UI. Both are `ClusterIP`, so they are reachable only from inside the cluster, or through the Kubernetes API server proxy and `kubectl port-forward`.

## Tell OpenCost where Prometheus is

OpenCost finds Prometheus through an environment variable, `PROMETHEUS_SERVER_ENDPOINT`. The Helm chart sets it from the values `opencost.prometheus.internal.namespaceName`, `serviceName` and `port`. Read the variable from the Deployment:

```sh
kubectl -n opencost get deploy opencost -o json | jq -r '.spec.template.spec.containers[0].env[] | select(.name == "PROMETHEUS_SERVER_ENDPOINT") | .value'
```

You should see:

```text
http://prometheus-server.monitoring.svc.cluster.local:80
```

This address is the Service `prometheus-server` in the namespace `monitoring`. If it pointed to the wrong Service, OpenCost would log a connection error at start-up. With the right address, its log shows that the `up` query worked. The line below is shortened: the date prefix and the colour codes are removed.

```sh
kubectl -n opencost logs deploy/opencost -c opencost | grep "retrieved the 'up' query" | sed 's/\x1b\[[0-9;]*m//g'
```

```text
2026-11-01T21:58:36.162525732Z INF Success: retrieved the 'up' query against prometheus at: http://prometheus-server.monitoring.svc.cluster.local:80
```

## Check what Prometheus scrapes

Prometheus must scrape three sources: the kubelet cAdvisor endpoint for container usage, kube-state-metrics for requests, and OpenCost for node prices. Ask the Prometheus targets API for the list from the `shuttle` pod:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://prometheus-server.monitoring.svc/api/v1/targets | jq -c '.data.activeTargets[] | {job: .labels.job, health}' | sort | uniq -c
```

The recorded result below predates the deliberate `probe-broken` job. It
shows the healthy data sources. Your list also includes `probe-broken` with
`health` set to `down`:

```text
   1 {"job":"kubernetes-api-servers","health":"up"}
   1 {"job":"kubernetes-nodes-cadvisor","health":"up"}
   1 {"job":"kubernetes-nodes","health":"up"}
   4 {"job":"kubernetes-service-endpoints","health":"up"}
   1 {"job":"opencost","health":"up"}
   1 {"job":"prometheus","health":"up"}
```

The job `kubernetes-nodes-cadvisor` carries the usage metrics. The job `kubernetes-service-endpoints` includes kube-state-metrics, which carries the requests. The job `opencost` is an extra scrape job that the playground adds in `prometheus-values.yaml`, with the address `opencost.opencost:9003`. The data-source jobs shown have `health` `up`. A failed scrape of one of these inputs can leave a gap in the cost. The extra `probe-broken` job fails on purpose; it supplies none of these inputs.

## Give OpenCost a price list

OpenCost reads the price list from a ConfigMap named `custom-pricing-model`. The chart creates it when the value `opencost.customPricing.enabled` is `true`. Without it, OpenCost finds no price for the cluster, logs `No pricing found for key=default, setting values to 0`, and computes every cost as `0`. Read the prices:

```sh
kubectl -n opencost get cm custom-pricing-model -o json | jq -c '.data | {provider, description, CPU, RAM, storage}'
```

You should see:

```text
{"provider":"custom","description":"OpenCost default on-premises prices","CPU":"0.031611","RAM":"0.004237","storage":"5.479452e-05"}
```

The three prices are in dollars for one hour: one CPU core, one gibibyte of memory and one gibibyte of storage. These are the default on-premises prices of OpenCost. In a cluster in a public cloud, OpenCost reads the real node prices from the cloud provider instead. You can now install OpenCost, point it at Prometheus, and prove that both its metrics and its prices are in place. The next question is how to ask the API for the costs, for a window of time and a grouping of your choice.

## Common pitfalls

> [!WARNING]
> - **Reading `Running` as "working".** A running pod with no price list returns `0` for every cost. Check the ConfigMap `custom-pricing-model`.
> - **Pointing OpenCost at the wrong Prometheus.** The endpoint is the Service name and port, `prometheus-server.monitoring.svc.cluster.local:80`. A wrong port makes every query fail.
> - **Forgetting the OpenCost scrape job.** Without it, Prometheus has no `node_cpu_hourly_cost` metric, and OpenCost cannot price the nodes.
> - **Judging the result in the first minutes.** Prometheus scrapes once a minute. The first cost appears about six minutes after the start, and the numbers settle after about fifteen minutes.
