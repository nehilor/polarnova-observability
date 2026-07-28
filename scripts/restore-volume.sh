#!/usr/bin/env bash
set -euo pipefail

VOLUME="${1:-}"
ARCHIVE="${2:-}"

if [[ -z "${VOLUME}" || -z "${ARCHIVE}" || ! -f "${ARCHIVE}" ]]; then
  echo "Usage: $0 <volume-name> <archive.tar.gz>" >&2
  exit 1
fi

echo "==> Restoring ${VOLUME} from ${ARCHIVE}"
read -r -p "Overwrite volume contents? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

docker volume create "${VOLUME}" >/dev/null
ABS="$(cd "$(dirname "${ARCHIVE}")" && pwd)/$(basename "${ARCHIVE}")"
docker run --rm \
  -v "${VOLUME}:/volume" \
  -v "${ABS}:/backup.tar.gz:ro" \
  alpine:3.21 \
  sh -c "rm -rf /volume/* /volume/.[!.]* 2>/dev/null; tar -xzf /backup.tar.gz -C /volume"
echo "==> Restore complete"
