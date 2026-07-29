# Upgrading

## Principles

1. **Pin versions** in `.env` — never rely on floating `latest` in production.
2. **Backup before every upgrade.**
3. Read [SigNoz releases](https://github.com/SigNoz/signoz/releases) for breaking changes.
4. Upgrade collector and SigNoz as a compatible pair when possible.

## Current pins

See `.env.example`:

- `IMAGE_SIGNOZ_TAG` (never `SIGNOZ_VERSION` — collides with SigNoz config)
- `IMAGE_OTELCOL_TAG`
- `IMAGE_CLICKHOUSE_TAG`
- `IMAGE_POSTGRES_TAG`
- `IMAGE_UPTIME_KUMA_TAG`

## Procedure

```bash
./scripts/backup-all.sh --volumes

# Edit .env — bump tags
vim .env

./scripts/upgrade.sh
./scripts/health-check.sh
```

Or via Coolify: change env → Deploy, then SSH health-check.

## ClickHouse upgrades

Minor ClickHouse bumps are usually fine. Major version jumps:

1. Backup volumes.
2. Read ClickHouse changelog.
3. Upgrade one step at a time when possible.
4. Confirm `schema-migrator` succeeds.

## Rollback

1. Stop stack: `docker compose down`
2. Restore volumes from pre-upgrade tarball.
3. Revert image tags in `.env`.
4. `docker compose up -d`

## After upgrade checklist

- [ ] SigNoz UI loads / login works
- [ ] `docker logs pn-obs-schema-migrator` shows success
- [ ] Collector healthy (`13133`)
- [ ] Test trace visible in SigNoz within 1–2 minutes
- [ ] Uptime Kuma monitors intact
- [ ] Disk usage normal (no runaway merges)
