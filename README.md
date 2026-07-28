# PolarNova Observability Platform

Centralized, self-hosted observability for every PolarNova product — APM, distributed tracing, metrics, logs, error tracking, infrastructure monitoring, and uptime/SSL checks.

**Stack:** [SigNoz](https://signoz.io) · OpenTelemetry Collector · ClickHouse · Uptime Kuma  
**Deploy:** Docker Compose via [Coolify](https://coolify.io)  
**License:** Open source components only — no SaaS, no free-tier lock-in.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PolarNova Products                                │
│  Vital AI · VoxPilot · Foodiiz · AI Drop Cloud · Operator · Future      │
│         OpenTelemetry SDKs (traces / metrics / logs / errors)            │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ OTLP gRPC :4317 / HTTP :4318
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              otel.polarnova.io  →  OpenTelemetry Collector               │
│         batch · filter · spanmetrics · resource enrichment               │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         ClickHouse (+ Zookeeper)                         │
│              signoz_traces · signoz_metrics · signoz_logs                │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              observe.polarnova.io  →  SigNoz UI / API / Alerts           │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  uptime.polarnova.io  →  Uptime Kuma                                     │
│  HTTP · TCP · SSL certs · keyword · ping  (apps, mail, DB, Coolify)      │
└─────────────────────────────────────────────────────────────────────────┘
```

| Service | Role |
|---------|------|
| **SigNoz** | Unified UI for traces, metrics, logs, dashboards, alerts, exceptions |
| **OTel Collector** | Ingestion pipeline (OTLP → ClickHouse) |
| **ClickHouse** | Columnar store for high-volume telemetry |
| **Zookeeper** | ClickHouse coordination |
| **Schema Migrator** | Bootstraps / upgrades SigNoz ClickHouse schemas |
| **Uptime Kuma** | Synthetic checks (HTTP, SSL, TCP, mail ports, etc.) |
| **Node Exporter / cAdvisor** | Optional host & Docker metrics (`--profile infra`) |

> Grafana, Loki, and Jaeger are intentionally **not** included — SigNoz covers those roles.

---

## Repository layout

```
.
├── docker-compose.yml          # Production stack (Coolify entrypoint)
├── .env.example                # All configurable variables
├── OBSERVABILITY_SETUP.md      # Spanish setup guide for PolarNova teams
├── config/
│   ├── clickhouse/             # ClickHouse server + cluster + retention
│   ├── otel/                   # Collector + OpAMP configs
│   ├── signoz/
│   └── uptime-kuma/            # Monitor checklist
├── scripts/                    # Backup, restore, health, upgrade
├── backups/                    # Local backup output (gitignored payloads)
├── docs/                       # Deep-dive documentation
├── examples/                   # SDK bootstrap snippets
└── .github/workflows/          # Compose validation CI
```

---

## Requirements

| Resource | Minimum | Recommended production |
|----------|---------|------------------------|
| CPU | 4 vCPU | 8+ vCPU |
| RAM | 8 GB | 16–32 GB |
| Disk | 100 GB SSD | 250+ GB SSD (telemetry grows fast) |
| Docker | Engine 20.10+ | Compose v2 plugin |
| OS | Linux x86_64 / arm64 | Ubuntu 22.04/24.04 |

---

## Quick start (local / VPS)

```bash
cp .env.example .env
./scripts/generate-secrets.sh

# Core stack
docker compose up -d

# Optional host + container metrics
docker compose --profile infra up -d

# Verify
./scripts/health-check.sh
```

Open:

- SigNoz → http://localhost:8080  
- Uptime Kuma → http://localhost:3001  

---

## Deploy with Coolify

1. Create a new **Docker Compose** resource in Coolify.
2. Connect this Git repository (branch `main`).
3. Set base directory to `/` (compose file: `docker-compose.yml`).
4. Copy variables from `.env.example` into Coolify **Environment Variables**.
5. Generate and set a strong `SIGNOZ_JWT_SECRET`.
6. Map domains:

| Domain | Service | Port |
|--------|---------|------|
| `observe.polarnova.io` | `signoz` | `8080` |
| `uptime.polarnova.io` | `uptime-kuma` | `3001` |
| `otel.polarnova.io` | `otel-collector` | `4318` (HTTPS) |

7. For OTLP **gRPC** (`4317`), add a TCP proxy / raw TCP service in Coolify (or expose the port on the host firewall to trusted networks only).
8. Enable HTTPS (Coolify + Let's Encrypt).
9. Deploy.

Detailed steps: [docs/deployment-coolify.md](docs/deployment-coolify.md)

---

## Ports & security

| Port | Protocol | Public? | Purpose |
|------|----------|---------|---------|
| 8080 | HTTP | Via Coolify TLS | SigNoz UI |
| 3001 | HTTP | Via Coolify TLS | Uptime Kuma |
| 4317 | gRPC | Restricted | OTLP gRPC ingestion |
| 4318 | HTTP | Via Coolify TLS | OTLP HTTP ingestion |
| 8123 / 9000 | ClickHouse | **Never** | Internal only |
| 2181 | Zookeeper | **Never** | Internal only |

- All services share the private Docker network `polarnova-observability`.
- Secrets live in environment variables — never hardcode passwords.
- Prefer network allowlists for `:4317` if you cannot terminate mTLS yet.

---

## Volumes

| Volume | Contents |
|--------|----------|
| `pn-obs-clickhouse-data` | Traces, metrics, logs |
| `pn-obs-clickhouse-logs` | ClickHouse server logs |
| `pn-obs-zookeeper-data` | ZK state |
| `pn-obs-signoz-data` | SigNoz SQLite metadata (users, dashboards, alerts) |
| `pn-obs-uptime-kuma-data` | Monitors & notification config |

---

## Connect an application

Point every PolarNova service at the collector:

```bash
OTEL_SERVICE_NAME=vital-ai-api
OTEL_SERVICE_NAMESPACE=polarnova
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.version=1.2.3
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.polarnova.io
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
```

Language guides: [docs/onboarding.md](docs/onboarding.md) · examples under `examples/`  
Spanish end-to-end guide: [OBSERVABILITY_SETUP.md](OBSERVABILITY_SETUP.md)

---

## Backup & restore

```bash
# Config + ClickHouse logical dump
./scripts/backup-all.sh

# Include Docker volume tarballs (heavier)
./scripts/backup-all.sh --volumes

# Restore ClickHouse
./scripts/restore-clickhouse.sh backups/clickhouse/<timestamp>

# Restore a volume
./scripts/restore-volume.sh pn-obs-signoz-data backups/volumes/<ts>/pn-obs-signoz-data.tar.gz
```

Full procedure: [docs/backups.md](docs/backups.md)

---

## Upgrade

1. Pin new image tags in `.env` (`SIGNOZ_VERSION`, `OTELCOL_VERSION`, …).
2. Read upstream SigNoz release notes.
3. Backup first: `./scripts/backup-all.sh --volumes`
4. Run `./scripts/upgrade.sh`
5. Validate with `./scripts/health-check.sh` and a test trace.

Details: [docs/upgrading.md](docs/upgrading.md)

---

## Monitoring targets

Applications, infra, and synthetic checks are catalogued in [docs/monitoring-targets.md](docs/monitoring-targets.md):

Vital AI · VoxPilot · Foodiiz · AI Drop Cloud · Operator · Mail · Database · AI Server · Coolify · Docker · Host · Redis · PostgreSQL · SMTP · IMAP · HTTP · SSL

---

## Documentation index

| Doc | Description |
|-----|-------------|
| [OBSERVABILITY_SETUP.md](OBSERVABILITY_SETUP.md) | Spanish setup for product teams |
| [docs/architecture.md](docs/architecture.md) | Component deep dive |
| [docs/deployment-coolify.md](docs/deployment-coolify.md) | Coolify runbook |
| [docs/onboarding.md](docs/onboarding.md) | New app onboarding |
| [docs/instrumentation/](docs/instrumentation/) | Per-framework SDK guides |
| [docs/backups.md](docs/backups.md) | Backup / restore |
| [docs/upgrading.md](docs/upgrading.md) | Version upgrades |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common failures |
| [docs/runbooks/](docs/runbooks/) | Incident runbooks |

---

## Operations cheatsheet

```bash
docker compose ps
docker compose logs -f signoz otel-collector clickhouse
docker compose restart otel-collector
./scripts/health-check.sh
```

Retention: configure in **SigNoz → Settings → Retention** (traces/metrics/logs) to control disk growth.

---

## Support

Internal PolarNova platform team. For SigNoz upstream issues see https://signoz.io/docs/
