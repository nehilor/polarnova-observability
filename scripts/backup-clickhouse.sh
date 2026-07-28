#!/usr/bin/env bash
# Backup ClickHouse databases used by SigNoz.
# Uses native clickhouse-client INSIDE the clickhouse container.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT_DIR}/.env" ]] && source "${ROOT_DIR}/.env"

BACKUP_ROOT="${BACKUP_ROOT:-${ROOT_DIR}/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
CONTAINER="${CLICKHOUSE_CONTAINER:-pn-obs-clickhouse}"
DATABASES="${CLICKHOUSE_BACKUP_DATABASES:-signoz_traces,signoz_metrics,signoz_logs,signoz_metadata,signoz_meter}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="${BACKUP_ROOT}/clickhouse/${STAMP}"

mkdir -p "${DEST}"

echo "==> ClickHouse backup → ${DEST}"

IFS=',' read -ra DB_LIST <<< "${DATABASES}"
for db in "${DB_LIST[@]}"; do
  db="$(echo "${db}" | xargs)"
  [[ -z "${db}" ]] && continue
  echo "  • dumping database: ${db}"
  mkdir -p "${DEST}/${db}"
  # Export each table as Native format for efficient restore
  tables="$(docker exec "${CONTAINER}" clickhouse-client --query "SHOW TABLES FROM ${db}" || true)"
  if [[ -z "${tables}" ]]; then
    echo "    (no tables or database missing — skipping)"
    continue
  fi
  while IFS= read -r table; do
    [[ -z "${table}" ]] && continue
    # Skip distributed / materialized views when dumping base data is preferred
    engine="$(docker exec "${CONTAINER}" clickhouse-client --query "SELECT engine FROM system.tables WHERE database='${db}' AND name='${table}'")"
    case "${engine}" in
      Distributed|MaterializedView|View|Dictionary)
        echo "    - skip ${table} (${engine})"
        continue
        ;;
    esac
    outfile="${DEST}/${db}/${table}.native.gz"
    echo "    - ${table}"
    docker exec "${CONTAINER}" clickhouse-client \
      --query "SELECT * FROM ${db}.${table} FORMAT Native" \
      | gzip -c > "${outfile}"
  done <<< "${tables}"
done

# Metadata sidecar
cat > "${DEST}/manifest.json" <<EOF
{
  "timestamp": "${STAMP}",
  "container": "${CONTAINER}",
  "databases": "${DATABASES}",
  "host": "$(hostname)",
  "type": "clickhouse-native-dump"
}
EOF

# Prune old backups
find "${BACKUP_ROOT}/clickhouse" -mindepth 1 -maxdepth 1 -type d -mtime "+${RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true

echo "==> Backup complete: ${DEST}"
echo "    Size: $(du -sh "${DEST}" | awk '{print $1}')"
