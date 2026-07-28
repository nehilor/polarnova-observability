#!/usr/bin/env bash
# Restore ClickHouse databases from a native dump created by backup-clickhouse.sh
#
# Usage:
#   ./scripts/restore-clickhouse.sh backups/clickhouse/20260728T120000Z
#
# WARNING: This overwrites matching tables. Stop writers (otel-collector) first.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT_DIR}/.env" ]] && source "${ROOT_DIR}/.env"

BACKUP_DIR="${1:-}"
CONTAINER="${CLICKHOUSE_CONTAINER:-pn-obs-clickhouse}"

if [[ -z "${BACKUP_DIR}" || ! -d "${BACKUP_DIR}" ]]; then
  echo "Usage: $0 <backup-directory>"
  echo "Example: $0 backups/clickhouse/20260728T120000Z"
  exit 1
fi

if [[ ! -f "${BACKUP_DIR}/manifest.json" ]]; then
  echo "ERROR: manifest.json not found in ${BACKUP_DIR}"
  exit 1
fi

echo "==> Restoring ClickHouse from ${BACKUP_DIR}"
echo "    Target container: ${CONTAINER}"
echo ""
read -r -p "This may overwrite existing tables. Continue? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

# Prefer stopping the collector to avoid concurrent writes
if docker ps --format '{{.Names}}' | grep -q '^pn-obs-otel-collector$'; then
  echo "==> Stopping otel-collector during restore"
  docker stop pn-obs-otel-collector >/dev/null
  RESTART_COLLECTOR=1
else
  RESTART_COLLECTOR=0
fi

for db_dir in "${BACKUP_DIR}"/*/; do
  [[ -d "${db_dir}" ]] || continue
  db="$(basename "${db_dir}")"
  echo "  • database: ${db}"
  docker exec "${CONTAINER}" clickhouse-client --query "CREATE DATABASE IF NOT EXISTS ${db}"

  for dump in "${db_dir}"*.native.gz; do
    [[ -f "${dump}" ]] || continue
    table="$(basename "${dump}" .native.gz)"
    echo "    - restoring ${table}"
    # Truncate then insert (table must already exist from schema migrator)
    docker exec "${CONTAINER}" clickhouse-client --query "TRUNCATE TABLE IF EXISTS ${db}.${table}" || true
    gunzip -c "${dump}" | docker exec -i "${CONTAINER}" clickhouse-client \
      --query "INSERT INTO ${db}.${table} FORMAT Native" || {
        echo "      WARN: restore failed for ${db}.${table} (engine may not support TRUNCATE/INSERT)"
      }
  done
done

if [[ "${RESTART_COLLECTOR}" -eq 1 ]]; then
  echo "==> Starting otel-collector"
  docker start pn-obs-otel-collector >/dev/null
fi

echo "==> Restore finished"
