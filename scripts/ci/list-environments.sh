#!/usr/bin/env bash
# Prints a JSON array of labs and playgrounds for a GitHub Actions matrix:
#   [{"kind":"lab","path":"sections/.../labs/lab-01"},
#    {"kind":"playground","path":"sections/.../playground"}, ...]
#
#   list-environments.sh                        # every section
#   list-environments.sh sections/section-030   # only these paths
#   list-environments.sh --changed-since <ref>  # sections changed since <ref>
#
# With --changed-since, a change to scripts/ or the labs workflow selects
# every section, because it can break any lab. Otherwise
# each section with a changed file is selected. No match prints [].
set -euo pipefail
cd "$(dirname "$0")/../.."

paths=()
if [ "${1:-}" = "--changed-since" ]; then
  ref=${2:?usage: list-environments.sh --changed-since <ref>}
  changed=$(git diff --name-only "$ref"...HEAD)
  if grep -qE '^(scripts/|astrona\.yaml$|TEACHING-COVERAGE\.yaml$|\.github/workflows/labs\.yml$)' <<<"$changed"; then
    paths=(sections)
  else
    while read -r section; do
      [ -d "$section" ] && paths+=("$section")
    done < <(grep -oE '^sections/section-[0-9]+' <<<"$changed" | sort -u)
  fi
  [ "${#paths[@]}" -gt 0 ] || { echo '[]'; exit 0; }
elif [ "$#" -gt 0 ]; then
  paths=("$@")
else
  paths=(sections)
fi

find "${paths[@]}" -name config.yaml \( -path '*/labs/lab-*/config.yaml' -o -path '*/playground/config.yaml' \) |
  sort |
  while read -r config; do
    dir=$(dirname "$config")
    case "$dir" in
      */playground) kind=playground ;;
      *) kind=lab ;;
    esac
    runtime=$(sed -n 's/^  type: //p' "$config" | head -n 1 | tr -d '"')
    runtime=${runtime:-kind}
    case "$runtime" in kind|qemu) ;; *) echo "Unsupported runtime: $runtime" >&2; exit 1 ;; esac
    printf '{"kind":"%s","path":"%s","runtime":"%s"}\n' "$kind" "$dir" "$runtime"
  done |
  jq -cs .
