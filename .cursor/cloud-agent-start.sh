#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # shellcheck disable=SC1091
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    . "$NVM_DIR/nvm.sh"
  fi
}

# Match the app's engines.node (^22). Do not install here; install owns that.
activate_node_22() {
  load_nvm
  if ! type nvm >/dev/null 2>&1; then
    return 0
  fi
  if ! nvm use 22; then
    echo "Node 22 is not installed; start is using $(command -v node) $(node -v)" >&2
    return 0
  fi
  local node_bin
  node_bin="$(nvm which 22)"
  export PATH="$(dirname "$node_bin"):${PATH}"
  hash -r
  echo "start node $(command -v node) $(node -v)"
}

activate_node_22

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

if ! OC="$(resolve_openclimbing)"; then
  echo "openclimbing checkout not found; cannot start the map app" >&2
  exit 1
fi

if [[ -x "$OC/.cursor/cloud-agent-start.sh" ]]; then
  exec bash "$OC/.cursor/cloud-agent-start.sh"
fi

cd "$OC"
if node -e 'const n=require("net");const s=n.connect(3000,"127.0.0.1",()=>{s.end();process.exit(0)});s.on("error",()=>process.exit(1));setTimeout(()=>process.exit(1),1000)'; then
  echo "dev server already listening on port 3000"
  exit 0
fi

exec yarn dev --hostname 0.0.0.0 --port 3000
