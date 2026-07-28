# Backup and restore

## What is durable

| Data | Volume | Notes |
|------|--------|-------|
| Telemetry | `pn-obs-clickhouse-data` | High growth |
| Keeper state | `pn-obs-clickhouse-keeper-data` | Coordination |
| UDF binaries | `pn-obs-clickhouse-user-scripts` | histogramQuantile |
| SigNoz metadata | `pn-obs-postgres-data` | **Critical** (users, dashboards, alerts) |
| Uptime monitors | `pn-obs-uptime-kuma-data` | High |

Runtime DB data is **named Docker volumes only** — never bind-mounted into the Git tree.

## Consistency rules (important)

| Method | Consistent? | When to use |
|--------|-------------|-------------|
| `backup-volumes.sh` with stack **stopped** | Yes | Pre-upgrade / weekly DR |
| Live `docker cp` / tar of running CH volume | **No** | Do not claim as backup |
| `backup-clickhouse.sh` with collector **stopped** | Best-effort logical | Daily export |
| Live logical dump while collector writes | Inconsistent risk | Avoid |

## Daily (logical)

```bash
cd /path/to/polarnova-observability
./scripts/backup-all.sh
# stops otel-collector briefly, dumps ClickHouse Native+gzip, restarts collector
# also archives config
```

Copy `backups/` off-box.

## Weekly / pre-upgrade (volumes)

```bash
docker compose stop
./scripts/backup-volumes.sh
./scripts/backup-config.sh
docker compose start
```

## Restore ClickHouse (logical)

```bash
./scripts/restore-clickhouse.sh backups/clickhouse/<timestamp>
```

Schema must already exist (migrator). Script stops `otel-collector` during restore.

## Restore a volume

```bash
docker compose stop
./scripts/restore-volume.sh pn-obs-postgres-data backups/volumes/<ts>/pn-obs-postgres-data.tar.gz
docker compose up -d
```

## Restore test (document result)

At least quarterly:

1. Restore postgres + clickhouse volumes on a **non-production** host or after snapshot.
2. `docker compose up -d`
3. `./scripts/health-check.sh`
4. Login to SigNoz; confirm dashboards present.
5. Record date + operator in your runbook log.

## Retention of backup files

`BACKUP_RETENTION_DAYS` (default 14) prunes local timestamped directories.
