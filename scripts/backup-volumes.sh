#!/usr/bin/env bash
# Tar named Docker volumes. Requires stack STOPPED for ClickHouse/Postgres consistency.
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
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="${BACKUP_ROOT}/volumes/${STAMP}"

VOLUMES=(
  pn-obs-clickhouse-data
  pn-obs-clickhouse-keeper-data
  pn-obs-clickhouse-user-scripts
  pn-obs-postgres-data
  pn-obs-uptime-kuma-data
)

if docker compose ps --status running --services 2>/dev/null | grep -E 'clickhouse|postgres' >/dev/null; then
  echo "ERROR: clickhouse/postgres still running. Stop the stack first for consistent volume backups:" >&2
  echo "  docker compose stop" >&2
  exit 1
fi

mkdir -p "${DEST}"
echo "==> Volume backup → ${DEST}"

for vol in "${VOLUMES[@]}"; do
  if ! docker volume inspect "${vol}" >/dev/null 2>&1; then
    echo "  • skip missing: ${vol}"
    continue
  fi
  echo "  • ${vol}"
  docker run --rm \
    -v "${vol}:/volume:ro" \
    -v "${DEST}:/backup" \
    alpine:3.21 \
    sh -c "tar -czf /backup/${vol}.tar.gz -C /volume ."
done

python3 - <<PY
import json
from pathlib import Path
Path("${DEST}/manifest.json").write_text(json.dumps({
  "timestamp": "${STAMP}",
  "volumes": $(printf '%s\n' "${VOLUMES[@]}" | python3 -c 'import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))'),
  "type": "docker-volume-tarball",
  "consistent": True,
  "prerequisite": "stack stopped"
}, indent=2))
PY

find "${BACKUP_ROOT}/volumes" -mindepth 1 -maxdepth 1 -type d -mtime "+${RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true
echo "==> Done ($(du -sh "${DEST}" | awk '{print $1}'))"
