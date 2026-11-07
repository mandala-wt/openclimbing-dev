#!/usr/bin/env bash
set -euo pipefail

# Workspace primary repo is openclimbing-dev; the OpenClimbing app lives in a
# sibling checkout (multi-repo Cloud Agent layout).
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$ROOT"

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # shellcheck disable=SC1091
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    . "$NVM_DIR/nvm.sh"
  fi
}

# `nvm which current` follows whichever node is already first on PATH, so a
# same-version binary such as /exec-daemon/node hides nvm. Resolve the
# requested major and put that bin directory first.
prepend_nvm_node() {
  local want="$1"
  local node_bin
  node_bin="$(nvm which "$want")"
  export PATH="$(dirname "$node_bin"):${PATH}"
  hash -r
}

use_node() {
  local want="$1"
  if ! type nvm >/dev/null 2>&1; then
    echo "nvm is not available; node $(command -v node) $(node -v) (want ${want}.x)"
    return 0
  fi
  if ! nvm use "$want"; then
    nvm install "$want"
  fi
  prepend_nvm_node "$want"
  echo "node $(command -v node) $(node -v) (want ${want}.x)"
}

resolve_openclimbing() {
  local candidate
  for candidate in \
    /agent/repos/openclimbing \
    "$ROOT/../openclimbing" \
    "$ROOT/../repos/openclimbing"; do
    if [[ -d "$candidate" && -f "$candidate/package.json" ]]; then
      readlink -f "$candidate"
      return 0
    fi
  done
  return 1
}

load_nvm

if ! OC="$(resolve_openclimbing)"; then
  echo "openclimbing checkout not found next to openclimbing-dev" >&2
  echo "expected /agent/repos/openclimbing or ../openclimbing" >&2
  exit 1
fi

echo "Installing OpenClimbing dependencies in $OC"
use_node 22
if ! command -v yarn >/dev/null 2>&1; then
  npm install -g yarn@1.22.22
fi
if [[ -x "$OC/.cursor/cloud-agent-install.sh" ]]; then
  bash "$OC/.cursor/cloud-agent-install.sh"
else
  (
    cd "$OC"
    yarn install --frozen-lockfile --network-timeout 600000
  )
fi

echo "Installing openclimbing-dev dependencies in $ROOT"
use_node 24
if [[ -f "$ROOT/package-lock.json" ]]; then
  npm ci
else
  npm install
fi

# nvm install can retarget the default alias. Keep Node 22 so later login
# shells still resolve the OpenClimbing yarn toolchain.
if type nvm >/dev/null 2>&1; then
  nvm alias default 22 >/dev/null
fi
