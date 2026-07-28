#!/usr/bin/env bash
# Soft-upgrade helper: pull pinned images from .env and recreate containers.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f .env ]]; then
  echo "Missing .env — copy from .env.example and generate secrets first."
  exit 1
fi

echo "==> Pulling images"
docker compose pull

echo "==> Recreating stack"
docker compose up -d --remove-orphans

echo "==> Waiting for health"
sleep 15
./scripts/health-check.sh

echo ""
echo "After upgrade:"
echo "  1. Confirm SigNoz UI loads"
echo "  2. Confirm schema-migrator exited 0: docker logs pn-obs-schema-migrator"
echo "  3. Send a test trace from any instrumented app"
