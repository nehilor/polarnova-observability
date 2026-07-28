# Backup & restore

## What to protect

| Data | Volume / path | Criticality |
|------|---------------|-------------|
| Telemetry | `pn-obs-clickhouse-data` | High (lossy OK with retention) |
| SigNoz metadata | `pn-obs-signoz-data` | **Critical** (users, dashboards, alerts) |
| Uptime monitors | `pn-obs-uptime-kuma-data` | High |
| Zookeeper | `pn-obs-zookeeper-data` | Medium |
| Git configs | `config/`, compose, `.env` | **Critical** |

## Recommended schedule

| Job | Frequency | Script |
|-----|-----------|--------|
| Config archive | Daily | `scripts/backup-config.sh` |
| ClickHouse dump | Daily | `scripts/backup-clickhouse.sh` |
| Volume tarballs | Weekly (or pre-upgrade) | `scripts/backup-volumes.sh` |
| Full | Weekly | `scripts/backup-all.sh --volumes` |

Store copies **off-box** (S3-compatible, another VPS, Backblaze, etc.).

Example cron on the observability host:

```cron
0 3 * * * cd /path/to/polarnova-observability && ./scripts/backup-all.sh >> /var/log/pn-obs-backup.log 2>&1
0 4 * * 0 cd /path/to/polarnova-observability && ./scripts/backup-all.sh --volumes >> /var/log/pn-obs-backup.log 2>&1
```

## ClickHouse logical backup

```bash
./scripts/backup-clickhouse.sh
# → backups/clickhouse/<UTC-timestamp>/
```

Produces per-table Native+gzip dumps for SigNoz databases.

Restore:

```bash
# Stop ingest preferred (script can stop collector)
./scripts/restore-clickhouse.sh backups/clickhouse/20260728T030000Z
```

Schema must already exist (schema-migrator). Restore loads data into existing tables.

## Volume backup

```bash
docker compose stop
./scripts/backup-volumes.sh
docker compose start
```

Restore one volume:

```bash
docker compose stop signoz
./scripts/restore-volume.sh pn-obs-signoz-data backups/volumes/<ts>/pn-obs-signoz-data.tar.gz
docker compose start signoz
```

## Config + secrets

`backup-config.sh` archives repo configs and, if present, copies `.env` to `backups/config/env-*.secret` (mode `600`).  
**Never commit** those secret copies.

## Disaster recovery outline

1. Provision new host / Coolify server.
2. Clone repo, restore `.env` from secret backup.
3. `docker compose up -d` (let schema-migrator run).
4. Stop stack; restore volumes **or** restore ClickHouse dumps + SigNoz/Uptime volumes.
5. Start stack; verify UI + test OTLP.
6. Re-point DNS if needed.

## Retention of backup files

Controlled by `BACKUP_RETENTION_DAYS` (default `14`). Adjust for compliance.
