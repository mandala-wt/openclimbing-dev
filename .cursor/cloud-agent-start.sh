#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

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
