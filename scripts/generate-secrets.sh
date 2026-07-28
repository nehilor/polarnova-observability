#!/usr/bin/env bash
# Generate production secrets into .env (local) — for Coolify, paste values in the UI.
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

replace_placeholder() {
  local key="$1"
  local placeholder_regex="$2"
  local value="$3"
  if grep -qE "^${key}=${placeholder_regex}" "${ENV_FILE}"; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' -E "s|^${key}=${placeholder_regex}|${key}=${value}|" "${ENV_FILE}"
    else
      sed -i -E "s|^${key}=${placeholder_regex}|${key}=${value}|" "${ENV_FILE}"
    fi
    echo "${key} generated"
  else
    echo "${key} already set — left unchanged"
  fi
}

replace_placeholder "SIGNOZ_JWT_SECRET" "CHANGE_ME_.*" "$(gen)"
replace_placeholder "POSTGRES_PASSWORD" "CHANGE_ME_.*" "$(gen)"

echo "Done. Review ${ENV_FILE} locally; configure Coolify env vars separately."
echo "Do not commit .env."
