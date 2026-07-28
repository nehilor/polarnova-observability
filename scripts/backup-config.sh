#!/usr/bin/env bash
# Backup configuration files (git-friendly + timestamped archive).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-${ROOT_DIR}/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST_DIR="${BACKUP_ROOT}/config"
ARCHIVE="${DEST_DIR}/polarnova-obs-config-${STAMP}.tar.gz"

mkdir -p "${DEST_DIR}"

echo "==> Config backup → ${ARCHIVE}"

tar -czf "${ARCHIVE}" \
  -C "${ROOT_DIR}" \
  --exclude='.git' \
  --exclude='backups' \
  --exclude='.env' \
  docker-compose.yml \
  .env.example \
  config \
  scripts \
  docs \
  README.md \
  OBSERVABILITY_SETUP.md \
  2>/dev/null || tar -czf "${ARCHIVE}" \
  -C "${ROOT_DIR}" \
  docker-compose.yml \
  .env.example \
  config \
  scripts

# Also copy .env separately (secrets) if present — NOT into git remotes
if [[ -f "${ROOT_DIR}/.env" ]]; then
  cp "${ROOT_DIR}/.env" "${DEST_DIR}/env-${STAMP}.secret"
  chmod 600 "${DEST_DIR}/env-${STAMP}.secret"
  echo "    secrets copy: ${DEST_DIR}/env-${STAMP}.secret (local only)"
fi

find "${DEST_DIR}" -type f -name 'polarnova-obs-config-*.tar.gz' -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true
find "${DEST_DIR}" -type f -name 'env-*.secret' -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true

echo "==> Done ($(du -h "${ARCHIVE}" | awk '{print $1}'))"
