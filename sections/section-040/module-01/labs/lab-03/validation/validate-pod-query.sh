#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
file="$RESULT_DIR/pods.json"
[ -s "$file" ] || fail 'pod-query: save the complete query response'
jq -e '.status == "success" and .data.resultType == "vector" and (.data.result | length > 0)
  and all(.data.result[]; .metric.__name__ == "kube_pod_info" and .metric.namespace == "starfleet"
    and (.metric.pod | length > 0) and (.value[0] | type == "number"))' "$file" >/dev/null \
  || fail 'pod-query: expected a nonempty starfleet kube_pod_info vector'
evaluation_time=$(jq -r '.data.result[0].value[0]' "$file")
live=$(kubectl get --raw "${PROMETHEUS_API}/query?query=kube_pod_info%7Bnamespace%3D%22starfleet%22%7D&time=${evaluation_time}")
# Compare all labels and values at the saved evaluation time, ignoring order.
jq -e --argjson live "$live" '
  (.data.result | sort_by(.metric | to_entries | sort_by(.key))) ==
  ($live.data.result | sort_by(.metric | to_entries | sort_by(.key)))
' "$file" >/dev/null || fail 'pod-query: saved data differs from Prometheus at its evaluation time'
echo 'PASS: pod-query'
