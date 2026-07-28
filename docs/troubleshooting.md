# Troubleshooting

## Containers restarting

```bash
docker compose ps
docker compose logs --tail=200 clickhouse clickhouse-keeper otel-collector signoz postgres
```

**OOM / ClickHouse kill:** raise host RAM or lower `CLICKHOUSE_MEMORY_LIMIT` / `max_server_memory_usage_to_ram_ratio` in `config/clickhouse/config.yaml`.

**Keeper unhealthy:** wait for `start_period`; inspect `pn-obs-clickhouse-keeper-data`.

## Schema migrator failed

```bash
docker compose logs schema-migrator
docker compose up schema-migrator
```

Ensure ClickHouse is healthy. Foundry sequence: `migrate ready && bootstrap && sync up && async up`.

## No data in SigNoz

1. Confirm `OTEL_EXPORTER_OTLP_ENDPOINT` is private (`http://otel-collector:4318` or Tailscale IP).
2. `docker compose logs otel-collector`
3. From another container: `wget -q -O- http://otel-collector:13133/`
4. Smoke JSON (on the Docker network):

```bash
curl -v http://otel-collector:4318/v1/traces \
  -H 'Content-Type: application/json' \
  -d @examples/otel-smoke-trace.json
```

## OTLP not reachable from another VPS

- OTLP is **not** public by design.
- Publish `4317/4318` only on the Tailscale IP (`OTLP_BIND_HOST` / Coolify Ports).
- Never bind `0.0.0.0`.

## SigNoz login / JWT

Rotating `SIGNOZ_JWT_SECRET` invalidates sessions.  
Lost admin: restore `pn-obs-postgres-data`.

## Disk full

1. `docker system df -v | grep pn-obs`
2. Lower SigNoz retention
3. Expand disk — never `docker compose down -v` without backup

## Uptime Kuma empty after redeploy

Restore `pn-obs-uptime-kuma-data`.
