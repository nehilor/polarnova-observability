#!/usr/bin/env bash
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
  docker-compose.yml \
  docker-compose.tailscale.yml \
  .env.example \
  config \
  scripts \
  docs \
  README.md \
  OBSERVABILITY_SETUP.md \
  SECURITY.md \
  BACKUP_AND_RESTORE.md \
  APPLICATION_ONBOARDING.md \
  COOLIFY_DEPLOYMENT_GUIDE.md \
  AUDIT_REPORT.md \
  2>/dev/null || tar -czf "${ARCHIVE}" -C "${ROOT_DIR}" docker-compose.yml .env.example config scripts

if [[ -f "${ROOT_DIR}/.env" ]]; then
  cp "${ROOT_DIR}/.env" "${DEST_DIR}/env-${STAMP}.secret"
  chmod 600 "${DEST_DIR}/env-${STAMP}.secret"
  echo "    local secrets copy written (gitignored)"
fi

find "${DEST_DIR}" -type f \( -name 'polarnova-obs-config-*.tar.gz' -o -name 'env-*.secret' \) -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true
echo "==> Done"
