#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
[ -s "$RESULT_DIR/target-error.txt" ] || fail 'scrape-error: save lastError'
targets=$(kubectl get --raw "${PROMETHEUS_API}/targets")
jq -e '[.data.activeTargets[] | select(.labels.job == "probe-broken" and .health == "down" and (.lastError | length > 0))] | length == 1' \
  <<<"$targets" >/dev/null || fail 'scrape-error: keep the probe-broken target present and down'
expected=$(jq -r '.data.activeTargets[] | select(.labels.job == "probe-broken") | .lastError' <<<"$targets")
[ "$(cat "$RESULT_DIR/target-error.txt")" = "$expected" ] || fail 'scrape-error: the saved text differs from the live lastError'
echo 'PASS: scrape-error'
