#!/usr/bin/env bash
# Generate production secrets for PolarNova Observability.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ENV_FILE}"
  echo "Created ${ENV_FILE} from .env.example"
fi

gen() {
  openssl rand -base64 48 | tr -d '\n' | tr '+/' '-_'
}

NEW_JWT="$(gen)"

if grep -q 'SIGNOZ_JWT_SECRET=CHANGE_ME' "${ENV_FILE}"; then
  # portable in-place replace
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "s|SIGNOZ_JWT_SECRET=CHANGE_ME_TO_A_LONG_RANDOM_STRING|SIGNOZ_JWT_SECRET=${NEW_JWT}|" "${ENV_FILE}"
  else
    sed -i "s|SIGNOZ_JWT_SECRET=CHANGE_ME_TO_A_LONG_RANDOM_STRING|SIGNOZ_JWT_SECRET=${NEW_JWT}|" "${ENV_FILE}"
  fi
  echo "SIGNOZ_JWT_SECRET generated and written to .env"
else
  echo "SIGNOZ_JWT_SECRET already set — left unchanged"
fi

echo "Done. Review ${ENV_FILE} before deploying."
