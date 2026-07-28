#!/usr/bin/env bash
# Quick health report for the PolarNova Observability stack.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "=============================================="
echo " PolarNova Observability — Health Check"
echo "=============================================="
echo ""

echo "▸ Containers"
docker compose ps || docker-compose ps
echo ""

check_http() {
  local name="$1" url="$2"
  if curl -fsS -o /dev/null -m 5 "${url}"; then
    printf "  OK   %-20s %s\n" "${name}" "${url}"
  else
    printf "  FAIL %-20s %s\n" "${name}" "${url}"
  fi
}

SIGNOZ_PORT="${SIGNOZ_HOST_PORT:-8080}"
OTLP_HTTP_PORT="${OTLP_HTTP_HOST_PORT:-4318}"
UPTIME_PORT="${UPTIME_KUMA_HOST_PORT:-3001}"

echo "▸ Endpoints (localhost)"
check_http "SigNoz"        "http://127.0.0.1:${SIGNOZ_PORT}/api/v1/health"
check_http "OTel health"   "http://127.0.0.1:13133/" 2>/dev/null || \
  docker exec pn-obs-otel-collector wget -q -O- http://localhost:13133/ >/dev/null \
    && printf "  OK   %-20s %s\n" "OTel health" "internal:13133" \
    || printf "  FAIL %-20s %s\n" "OTel health" "internal:13133"
check_http "Uptime Kuma"   "http://127.0.0.1:${UPTIME_PORT}"
check_http "ClickHouse"    "" >/dev/null 2>&1 || true
if docker exec pn-obs-clickhouse wget -q -O- http://127.0.0.1:8123/ping 2>/dev/null | grep -q Ok; then
  printf "  OK   %-20s %s\n" "ClickHouse" "internal:8123/ping"
else
  printf "  FAIL %-20s %s\n" "ClickHouse" "internal:8123/ping"
fi

echo ""
echo "▸ OTLP smoke (HTTP)"
if curl -fsS -o /dev/null -m 5 -X POST "http://127.0.0.1:${OTLP_HTTP_PORT}/v1/traces" \
  -H 'Content-Type: application/json' \
  -d '{}' ; then
  echo "  OTLP HTTP reachable (empty payload may return 400 — that is OK)"
else
  code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' -X POST "http://127.0.0.1:${OTLP_HTTP_PORT}/v1/traces" -H 'Content-Type: application/json' -d '{}' || true)"
  if [[ "${code}" =~ ^(200|400|415)$ ]]; then
    echo "  OK   OTLP HTTP responding (HTTP ${code})"
  else
    echo "  FAIL OTLP HTTP (HTTP ${code:-unreachable})"
  fi
fi

echo ""
echo "▸ Disk (Docker volumes)"
docker system df -v 2>/dev/null | grep -E 'pn-obs-|VOLUME' | head -20 || true
echo ""
echo "Done."
