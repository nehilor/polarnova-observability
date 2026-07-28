#!/usr/bin/env bash
# Snapshot Docker named volumes used by the observability stack.
# Requires: docker, gzip. Prefer offline (stack stopped) for consistency.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT_DIR}/.env" ]] && source "${ROOT_DIR}/.env"

BACKUP_ROOT="${BACKUP_ROOT:-${ROOT_DIR}/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="${BACKUP_ROOT}/volumes/${STAMP}"
PROJECT="${COMPOSE_PROJECT_NAME:-polarnova-observability}"

VOLUMES=(
  pn-obs-clickhouse-data
  pn-obs-clickhouse-logs
  pn-obs-zookeeper-data
  pn-obs-signoz-data
  pn-obs-uptime-kuma-data
)

mkdir -p "${DEST}"

echo "==> Volume backup → ${DEST}"
echo "    Tip: for crash-consistent ClickHouse data, stop the stack first:"
echo "         docker compose -p ${PROJECT} stop"
echo ""

for vol in "${VOLUMES[@]}"; do
  if ! docker volume inspect "${vol}" >/dev/null 2>&1; then
    echo "  • skip missing volume: ${vol}"
    continue
  fi
  echo "  • ${vol}"
  docker run --rm \
    -v "${vol}:/volume:ro" \
    -v "${DEST}:/backup" \
    alpine:3.21 \
    sh -c "tar -czf /backup/${vol}.tar.gz -C /volume ."
done

cat > "${DEST}/manifest.json" <<EOF
{
  "timestamp": "${STAMP}",
  "volumes": $(printf '%s\n' "${VOLUMES[@]}" | python3 -c 'import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))'),
  "type": "docker-volume-tarball"
}
EOF

find "${BACKUP_ROOT}/volumes" -mindepth 1 -maxdepth 1 -type d -mtime "+${RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true

echo "==> Volume backup complete: ${DEST}"
du -sh "${DEST}"
