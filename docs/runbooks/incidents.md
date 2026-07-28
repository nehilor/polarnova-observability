# Incident runbooks

## R1 — Ingest outage (no new telemetry)

1. `./scripts/health-check.sh`
2. `docker compose logs --tail=100 otel-collector clickhouse`
3. If ClickHouse unhealthy → check disk (`df -h`) and memory.
4. If collector unhealthy → restart `docker compose restart otel-collector`.
5. Confirm apps still have correct `OTEL_EXPORTER_OTLP_ENDPOINT`.
6. Notify product teams if outage &gt; 15 minutes.

## R2 — Disk full on observability host

1. Identify volume: `docker system df -v | grep pn-obs`
2. Lower SigNoz retention immediately.
3. Delete old local backups under `backups/` if safe.
4. Expand disk / volume.
5. Avoid `docker compose down -v` (destroys data).

## R3 — SigNoz UI unavailable but ingest OK

1. Check `pn-obs-signoz` logs/health.
2. Restart signoz only: `docker compose restart signoz`.
3. If SQLite corruption suspected → restore `pn-obs-signoz-data` from backup.

## R4 — False uptime alerts

1. Check Coolify proxy / certificate renewals.
2. Confirm monitor URL and accepted status codes.
3. Mute with note if planned maintenance.

## R5 — Suspected data loss after deploy

1. Stop writes: `docker compose stop otel-collector`
2. Restore ClickHouse and/or volumes from last good backup.
3. Start stack; verify with test trace.
4. Post-mortem: why backup was needed (tag upgrade? volume wipe?).
