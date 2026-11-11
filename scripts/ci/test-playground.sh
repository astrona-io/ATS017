#!/usr/bin/env bash
# Starts one playground, runs its smoke test, and always destroys it.
#
#   scripts/ci/test-playground.sh sections/section-030/module-10/playground
#
# 1. `astrona run` must finish: the bootstrap and every waitFor in config.yaml
#    pass.
# 2. If the playground has testing/smoke.sh, it runs with KUBECONFIG set to
#    the playground cluster. The smoke test runs the commands the pages teach
#    and exits non-zero when one of them does not give the expected result.
#
# The script uses its own kubeconfig file, so it never changes the current
# context of the machine it runs on.
set -euo pipefail

dir=${1:?usage: test-playground.sh <playground directory>}
dir=$(cd "$dir" && pwd)
name=$(python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["metadata"]["name"])' "$dir/config.yaml")
work=$(mktemp -d)
export KUBECONFIG="$work/kubeconfig-start"

cleanup() {
  status=$?
  if [ "$status" -ne 0 ] && [ -n "${DIAGNOSTICS_DIR:-}" ]; then
    astrona diagnose "$name" -o "$DIAGNOSTICS_DIR/$name" --accept-terms --headless || true
  fi
  astrona destroy "$name" --accept-terms --headless </dev/null >/dev/null 2>&1 || true
  rm -rf "$work"
  echo "destroyed $name"
  exit "$status"
}
trap cleanup EXIT

echo "::group::astrona run $name"
(cd "$dir" && astrona run -c . --headless --accept-terms --trust --keep-context --yes)
echo "::endgroup::"

# In CI astrona can print a terms notice first, so take the path line only.
KUBECONFIG=$(astrona kubeconfig "$name" --accept-terms --headless 2>/dev/null | grep -m1 "/kubeconfig$")
[ -f "$KUBECONFIG" ] || { echo "no kubeconfig file for $name" >&2; exit 1; }
export KUBECONFIG
echo "cluster context: $(kubectl config current-context)"

if [ -x "$dir/testing/smoke.sh" ]; then
  echo "::group::smoke test $name"
  "$dir/testing/smoke.sh"
  echo "::endgroup::"
else
  echo "no testing/smoke.sh: only the start and the readiness checks were tested"
fi
echo "PASS $name"
