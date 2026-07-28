#!/usr/bin/env bash
# Full backup: config + ClickHouse logical dump + (optional) volumes.
# Usage: ./scripts/backup-all.sh [--volumes]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INCLUDE_VOLUMES=0
[[ "${1:-}" == "--volumes" ]] && INCLUDE_VOLUMES=1

echo "==> PolarNova Observability full backup"
"${ROOT_DIR}/scripts/backup-config.sh"
"${ROOT_DIR}/scripts/backup-clickhouse.sh"
if [[ "${INCLUDE_VOLUMES}" -eq 1 ]]; then
  "${ROOT_DIR}/scripts/backup-volumes.sh"
else
  echo "==> Skipping volume tarballs (pass --volumes to include)"
fi
echo "==> All requested backups finished"
