#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f .env ]]; then
  echo "Missing .env — create from .env.example / Coolify env first." >&2
  exit 1
fi

echo "==> Pull"
docker compose pull
echo "==> Recreate"
docker compose up -d --remove-orphans
echo "==> Wait"
sleep 20
./scripts/health-check.sh
