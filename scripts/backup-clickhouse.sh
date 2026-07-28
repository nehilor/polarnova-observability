#!/usr/bin/env bash
# Logical ClickHouse backup (requires stop of writers for consistency — see docs).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

BACKUP_ROOT="${BACKUP_ROOT:-${ROOT_DIR}/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
SERVICE="${CLICKHOUSE_SERVICE:-clickhouse}"
DATABASES="${CLICKHOUSE_BACKUP_DATABASES:-signoz_traces,signoz_metrics,signoz_logs,signoz_metadata,signoz_meter}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="${BACKUP_ROOT}/clickhouse/${STAMP}"
COMPOSE=(docker compose)

if ! "${COMPOSE[@]}" ps --status running --services 2>/dev/null | grep -qx "${SERVICE}"; then
  echo "ERROR: service '${SERVICE}' is not running" >&2
  exit 1
fi

mkdir -p "${DEST}"
echo "==> ClickHouse logical backup → ${DEST}"
echo "    NOTE: For consistent snapshots, stop otel-collector first (see BACKUP_AND_RESTORE.md)."

IFS=',' read -ra DB_LIST <<< "${DATABASES}"
for db in "${DB_LIST[@]}"; do
  db="$(echo "${db}" | xargs)"
  [[ -z "${db}" ]] && continue
  echo "  • database: ${db}"
  mkdir -p "${DEST}/${db}"
  tables="$("${COMPOSE[@]}" exec -T "${SERVICE}" clickhouse-client --query "SHOW TABLES FROM ${db}" 2>/dev/null || true)"
  if [[ -z "${tables}" ]]; then
    echo "    (no tables — skipping)"
    continue
  fi
  while IFS= read -r table; do
    [[ -z "${table}" ]] && continue
    engine="$("${COMPOSE[@]}" exec -T "${SERVICE}" clickhouse-client --query "SELECT engine FROM system.tables WHERE database='${db}' AND name='${table}'")"
    case "${engine}" in
      Distributed|MaterializedView|View|Dictionary)
        echo "    - skip ${table} (${engine})"
        continue
        ;;
    esac
    echo "    - ${table}"
    "${COMPOSE[@]}" exec -T "${SERVICE}" clickhouse-client \
      --query "SELECT * FROM ${db}.${table} FORMAT Native" \
      | gzip -c > "${DEST}/${db}/${table}.native.gz"
  done <<< "${tables}"
done

cat > "${DEST}/manifest.json" <<EOF
{
  "timestamp": "${STAMP}",
  "service": "${SERVICE}",
  "databases": "${DATABASES}",
  "type": "clickhouse-native-dump",
  "consistent": false,
  "note": "Stop otel-collector before backup for crash-consistent data"
}
EOF

find "${BACKUP_ROOT}/clickhouse" -mindepth 1 -maxdepth 1 -type d -mtime "+${RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true
echo "==> Complete ($(du -sh "${DEST}" | awk '{print $1}'))"
