#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INCLUDE_VOLUMES=0
[[ "${1:-}" == "--volumes" ]] && INCLUDE_VOLUMES=1

echo "==> PolarNova Observability backup"
"${ROOT_DIR}/scripts/backup-config.sh"
if [[ "${INCLUDE_VOLUMES}" -eq 1 ]]; then
  "${ROOT_DIR}/scripts/backup-volumes.sh"
else
  echo "==> Stopping otel-collector for quieter ClickHouse dump"
  (cd "${ROOT_DIR}" && docker compose stop otel-collector || true)
  "${ROOT_DIR}/scripts/backup-clickhouse.sh"
  (cd "${ROOT_DIR}" && docker compose start otel-collector || true)
  echo "==> Tip: pass --volumes after 'docker compose stop' for crash-consistent volume tarballs"
fi
echo "==> Finished"
