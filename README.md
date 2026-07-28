# PolarNova Observability Platform

Self-hosted observability for Vital AI, VoxPilot, Foodiiz, AI Drop Cloud, Operator, and future products.

| Layer | Technology |
|-------|------------|
| APM / traces / metrics / logs / alerts | **SigNoz** `v0.134.0` |
| Telemetry store | **ClickHouse** `25.12.5` + **ClickHouse Keeper** |
| Metastore | **PostgreSQL** `16` |
| Ingest | **SigNoz OpenTelemetry Collector** `v0.144.6` |
| Synthetic checks | **Uptime Kuma** `1.23.16` |
| Deploy | **Coolify v4** + Docker Compose + Traefik |

**Not included:** Grafana, Loki, Jaeger, GlitchTip, Prometheus server, cAdvisor.

Architecture follows current SigNoz **Foundry** Docker defaults (post-v0.130), adapted for Coolify.

---

## Public vs private

| Surface | Exposure |
|---------|----------|
| SigNoz UI | Public via Coolify: `https://observe.polarnova.io` → service `signoz:8080` |
| Uptime Kuma | Private until auth + optional `uptime.polarnova.io` |
| OTLP `:4317/:4318` | **Private** — Docker network and/or Tailscale IP only |
| ClickHouse / Keeper / Postgres | **Never** published |

See [SECURITY.md](SECURITY.md) and [COOLIFY_DEPLOYMENT_GUIDE.md](COOLIFY_DEPLOYMENT_GUIDE.md) (español).

---

## Quick links

| Doc | Purpose |
|-----|---------|
| [COOLIFY_DEPLOYMENT_GUIDE.md](COOLIFY_DEPLOYMENT_GUIDE.md) | Despliegue Coolify paso a paso (ES) |
| [OBSERVABILITY_SETUP.md](OBSERVABILITY_SETUP.md) | Guía operativa en español |
| [APPLICATION_ONBOARDING.md](APPLICATION_ONBOARDING.md) | SDKs + canonical service names |
| [BACKUP_AND_RESTORE.md](BACKUP_AND_RESTORE.md) | Backups consistentes |
| [SECURITY.md](SECURITY.md) | Modelo de amenaza / Tailscale |
| [AUDIT_REPORT.md](AUDIT_REPORT.md) | Auditoría pre-producción |

---

## Repository layout

```
docker-compose.yml              # Coolify entrypoint
docker-compose.tailscale.yml    # Optional OTLP bind to Tailscale IP
.env.example
config/clickhouse/              # Foundry-aligned CH config
config/clickhouse-keeper/
config/otel/
scripts/                        # backup / restore / health / upgrade
```

---

## Coolify deploy (summary)

1. New Resource → **Docker Compose** → Git branch **`main`** → file **`docker-compose.yml`**
2. Set `SIGNOZ_JWT_SECRET` and `POSTGRES_PASSWORD`
3. Domain on service **`signoz`**: `https://observe.polarnova.io:8080`
4. Deploy → create SigNoz admin → set retention
5. Wire apps to `http://otel-collector:4318` or Tailscale IP (never public OTLP domain)

---

## Local validation

```bash
cp .env.example .env
./scripts/generate-secrets.sh
docker compose config --quiet
# Full stack only on a suitably sized host:
# docker compose up -d && ./scripts/health-check.sh
```

---

## Retention targets (shared VPS)

Configure in SigNoz UI after login (env vars `RETENTION_*_DAYS` are operational targets):

- Traces: 7 days  
- Metrics: 15 days  
- Logs: 7 days  

Resource limits default to conservative values in `.env.example` (ClickHouse 4G, collector 1.5G, SigNoz 1.5G).
