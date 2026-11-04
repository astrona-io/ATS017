#!/usr/bin/env bash
# Install the exact release on the terminal, where kubectl finds plugins.
set -euo pipefail
PLUGIN_VERSION=v0.6.6
for tool in kubectl helm curl jq tar; do
  command -v "$tool" >/dev/null || { echo "Missing terminal tool: $tool" >&2; exit 1; }
done
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) platform=darwin-arm64 ;;
  Darwin/x86_64) platform=darwin-amd64 ;;
  Linux/x86_64) platform=linux-amd64 ;;
  *) echo "kubectl-cost ${PLUGIN_VERSION} has no release binary for this terminal" >&2; exit 1 ;;
esac
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
curl --fail --silent --show-error --location   "https://github.com/kubecost/kubectl-cost/releases/download/${PLUGIN_VERSION}/kubectl-cost-${platform}.tar.gz"   --output "$work_dir/plugin.tar.gz"
tar -xzf "$work_dir/plugin.tar.gz" -C "$work_dir"
# Use the directory that already supplies kubectl, so PATH needs no change.
terminal_bin=$(dirname "$(command -v kubectl)")
if [ -w "$terminal_bin" ]; then
  install -m 0755 "$work_dir/kubectl-cost" "$terminal_bin/kubectl-cost"
else
  sudo install -m 0755 "$work_dir/kubectl-cost" "$terminal_bin/kubectl-cost"
fi
kubectl cost version 2>&1 | grep -F "$PLUGIN_VERSION" >/dev/null
