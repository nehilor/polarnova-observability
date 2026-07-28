#!/usr/bin/env bash
# Restore a single Docker volume from a tarball produced by backup-volumes.sh
#
# Usage:
#   ./scripts/restore-volume.sh pn-obs-signoz-data backups/volumes/20260728T120000Z/pn-obs-signoz-data.tar.gz
set -euo pipefail

VOLUME="${1:-}"
ARCHIVE="${2:-}"

if [[ -z "${VOLUME}" || -z "${ARCHIVE}" || ! -f "${ARCHIVE}" ]]; then
  echo "Usage: $0 <volume-name> <archive.tar.gz>"
  exit 1
fi

echo "==> Restoring ${VOLUME} from ${ARCHIVE}"
read -r -p "Existing volume data will be overwritten. Continue? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

docker volume create "${VOLUME}" >/dev/null
docker run --rm \
  -v "${VOLUME}:/volume" \
  -v "$(cd "$(dirname "${ARCHIVE}")" && pwd)/$(basename "${ARCHIVE}"):/backup.tar.gz:ro" \
  alpine:3.21 \
  sh -c "rm -rf /volume/* /volume/.[!.]* 2>/dev/null; tar -xzf /backup.tar.gz -C /volume"

echo "==> Restore complete"
