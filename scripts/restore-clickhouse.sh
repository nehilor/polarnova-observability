#!/usr/bin/env bash
# Restore ClickHouse native dumps. Stops otel-collector during restore.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

BACKUP_DIR="${1:-}"
SERVICE="${CLICKHOUSE_SERVICE:-clickhouse}"
COMPOSE=(docker compose)

if [[ -z "${BACKUP_DIR}" || ! -d "${BACKUP_DIR}" ]]; then
  echo "Usage: $0 <backup-directory>" >&2
  exit 1
fi
if [[ ! -f "${BACKUP_DIR}/manifest.json" ]]; then
  echo "ERROR: manifest.json missing in ${BACKUP_DIR}" >&2
  exit 1
fi

echo "==> Restoring from ${BACKUP_DIR}"
read -r -p "Overwrite matching tables? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

RESTART_COLLECTOR=0
if "${COMPOSE[@]}" ps --status running --services 2>/dev/null | grep -qx otel-collector; then
  echo "==> Stopping otel-collector"
  "${COMPOSE[@]}" stop otel-collector
  RESTART_COLLECTOR=1
fi

for db_dir in "${BACKUP_DIR}"/*/; do
  [[ -d "${db_dir}" ]] || continue
  db="$(basename "${db_dir}")"
  echo "  • ${db}"
  "${COMPOSE[@]}" exec -T "${SERVICE}" clickhouse-client --query "CREATE DATABASE IF NOT EXISTS ${db}"
  for dump in "${db_dir}"*.native.gz; do
    [[ -f "${dump}" ]] || continue
    table="$(basename "${dump}" .native.gz)"
    echo "    - ${table}"
    "${COMPOSE[@]}" exec -T "${SERVICE}" clickhouse-client --query "TRUNCATE TABLE IF EXISTS ${db}.${table}" || true
    if ! gunzip -c "${dump}" | "${COMPOSE[@]}" exec -T "${SERVICE}" clickhouse-client \
      --query "INSERT INTO ${db}.${table} FORMAT Native"; then
      echo "      WARN: failed ${db}.${table}" >&2
    fi
  done
done

if [[ "${RESTART_COLLECTOR}" -eq 1 ]]; then
  "${COMPOSE[@]}" start otel-collector
fi
echo "==> Restore finished"
