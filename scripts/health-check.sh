#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "=============================================="
echo " PolarNova Observability — Health Check"
echo "=============================================="

docker compose ps || true
echo ""

ok() { printf "  OK   %s\n" "$1"; }
fail() { printf "  FAIL %s\n" "$1"; FAILURES=$((FAILURES + 1)); }
FAILURES=0

# SigNoz readiness via compose network
if docker compose exec -T signoz wget -q -O- http://127.0.0.1:8080/api/v1/health >/dev/null 2>&1; then
  ok "signoz /api/v1/health"
else
  fail "signoz /api/v1/health"
fi

if docker compose exec -T clickhouse wget -q -O- http://127.0.0.1:8123/ping 2>/dev/null | grep -q Ok; then
  ok "clickhouse /ping"
else
  fail "clickhouse /ping"
fi

if docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-signoz}" -d "${POSTGRES_DB:-signoz}" >/dev/null 2>&1; then
  ok "postgres pg_isready"
else
  fail "postgres pg_isready"
fi

if docker compose exec -T clickhouse-keeper clickhouse-keeper-client -h localhost -p 9181 -q ls >/dev/null 2>&1; then
  ok "clickhouse-keeper"
else
  fail "clickhouse-keeper"
fi

# Collector health extension (may fail if wget absent — try from clickhouse net)
if docker compose exec -T clickhouse wget -q -O- http://otel-collector:13133/ >/dev/null 2>&1; then
  ok "otel-collector :13133"
else
  fail "otel-collector :13133 (check logs: docker compose logs otel-collector)"
fi

if docker compose ps --status running --services 2>/dev/null | grep -qx uptime-kuma; then
  ok "uptime-kuma running (private — no public probe)"
else
  fail "uptime-kuma not running"
fi

echo ""
if [[ "${FAILURES}" -gt 0 ]]; then
  echo "Result: ${FAILURES} check(s) failed"
  exit 1
fi
echo "Result: all checks passed"
