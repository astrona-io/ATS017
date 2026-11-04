#!/usr/bin/env bash
# Keep the terminal's working Git. Build the pinned release only when none works.
set -euo pipefail
GIT_VERSION=2.56.0
GIT_PREFIX="$HOME/.local/ats017-git-${GIT_VERSION}"
if git --version >/dev/null 2>&1; then
  exit 0
fi
if [ ! -x "$GIT_PREFIX/bin/git" ]; then
  for tool in curl tar make cc perl; do
    command -v "$tool" >/dev/null || { echo "Install Git, or install this Git build prerequisite: $tool" >&2; exit 1; }
  done
  work_dir=$(mktemp -d)
  trap 'rm -rf "$work_dir"' EXIT
  curl --fail --silent --show-error --location \
    "https://www.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz" \
    --output "$work_dir/git.tar.gz"
  tar -xzf "$work_dir/git.tar.gz" -C "$work_dir"
  cd "$work_dir/git-${GIT_VERSION}"
  # This lab needs only local history. Omit remote transports and optional UIs.
  make -j2 prefix="$GIT_PREFIX" NO_CURL=YesPlease NO_EXPAT=YesPlease \
    NO_GETTEXT=YesPlease NO_TCLTK=YesPlease NO_OPENSSL=YesPlease all
  make prefix="$GIT_PREFIX" NO_CURL=YesPlease NO_EXPAT=YesPlease \
    NO_GETTEXT=YesPlease NO_TCLTK=YesPlease NO_OPENSSL=YesPlease install
fi
# Use the directory that already supplies kubectl, so PATH needs no change.
terminal_bin=$(dirname "$(command -v kubectl)")
if [ -w "$terminal_bin" ]; then
  ln -sf "$GIT_PREFIX/bin/git" "$terminal_bin/git"
else
  sudo ln -sf "$GIT_PREFIX/bin/git" "$terminal_bin/git"
fi
git --version | grep -F "$GIT_VERSION" >/dev/null
