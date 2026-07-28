# Troubleshooting

## Containers restarting

```bash
docker compose ps
docker compose logs --tail=200 clickhouse
docker compose logs --tail=200 otel-collector
docker compose logs --tail=200 signoz
```

**OOM / ClickHouse kill:** increase host RAM or lower `CLICKHOUSE_MEMORY_LIMIT` / `max_server_memory_usage_to_ram_ratio` in `config/clickhouse/config.d/memory.xml`.

**Zookeeper unhealthy:** wait for start_period; check `pn-obs-zookeeper-data` permissions.

## Schema migrator failed

```bash
docker logs pn-obs-schema-migrator
```

Ensure ClickHouse is healthy and reachable at `clickhouse:9000`. Re-run:

```bash
docker compose up schema-migrator
```

## No data in SigNoz

1. Confirm app `OTEL_EXPORTER_OTLP_ENDPOINT` points to the collector.
2. For HTTPS: use `http/protobuf` and correct path base (no trailing slash issues).
3. Check collector logs for export errors.
4. Send a manual smoke span (see below).
5. Verify time sync (NTP) on app and obs hosts.

### HTTP smoke (OTLP)

```bash
# Requires an OTLP JSON payload — easier with a tiny SDK script from examples/
curl -v https://otel.polarnova.io/v1/traces \
  -H 'Content-Type: application/json' \
  -d @examples/otel-smoke-trace.json
```

## OTLP 502 / 504 behind Coolify

- Increase proxy timeouts for `otel.polarnova.io`.
- Disable response buffering if available.
- Confirm Coolify routes to port `4318`.

## SigNoz login / JWT issues

If you rotated `SIGNOZ_JWT_SECRET`, existing sessions invalidate — that is expected.  
If you lost the admin user, restore `pn-obs-signoz-data` from backup.

## Disk full

1. Check `docker system df` and ClickHouse volume size.
2. Reduce retention in SigNoz UI.
3. `OPTIMIZE` / wait for TTL merges (or free disk urgently by extending volume).

## Uptime Kuma empty after redeploy

Volume `pn-obs-uptime-kuma-data` was not preserved — restore from backup.

## Collector scrape errors for node-exporter

Normal if `--profile infra` is not enabled. Remove those scrape jobs or enable the profile.
