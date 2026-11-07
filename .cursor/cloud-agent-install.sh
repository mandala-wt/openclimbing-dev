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

use_node() {
  local want="$1"
  if command -v nvm >/dev/null 2>&1 || type nvm >/dev/null 2>&1; then
    nvm use "$want" >/dev/null || nvm install "$want"
  fi
  echo "node $(node -v) (want ${want}.x)"
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
if [[ -x "$OC/.cursor/cloud-agent-install.sh" ]]; then
  bash "$OC/.cursor/cloud-agent-install.sh"
else
  if ! command -v yarn >/dev/null 2>&1; then
    echo "yarn is not on PATH" >&2
    exit 1
  fi
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
