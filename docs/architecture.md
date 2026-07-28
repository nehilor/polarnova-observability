# Architecture

## Design goals

1. **Single pane of glass** for all PolarNova products (APM + traces + metrics + logs + alerts).
2. **OpenTelemetry-native** ingestion — vendor-neutral SDKs in every app.
3. **Self-hosted** — data never leaves PolarNova infrastructure.
4. **Coolify-friendly** — one Git repo, one Compose file, domain mapping, TLS at the edge.
5. **Operable** — backups, health checks, pinned versions, resource limits.

## Data path

```
App SDK ──OTLP──▶ OTel Collector ──▶ ClickHouse ◀── SigNoz Query/UI
                       │
                       ├── processors: memory_limiter, filter, attributes, batch
                       ├── spanmetrics → RED metrics derived from traces
                       └── prometheus scrape → node-exporter / cAdvisor / ClickHouse
```

## Why these components

| Choice | Rationale |
|--------|-----------|
| SigNoz | Unified OSS alternative to Datadog; ClickHouse-backed; OTel-first |
| SigNoz OTel Collector | Correct ClickHouse exporters + schema awareness |
| ClickHouse | High ingest, fast analytical queries, proven with SigNoz |
| Zookeeper | Required for SigNoz replicated table coordination in this layout |
| Uptime Kuma | Lightweight synthetic monitoring (HTTP/SSL/TCP) without Grafana |
| SQLite for SigNoz metadata | Simple Coolify ops; volume-backed; adequate for single-node |

## What we deliberately excluded

- **Grafana / Loki / Tempo / Jaeger** — duplicated by SigNoz.
- **SaaS APM** — out of scope (self-hosted only).
- **Enterprise-only features** — stack stays on community images.

## Networks

- `polarnova-observability` (bridge): all stack services.
- Application containers on other Coolify projects should either:
  - Export OTLP to `https://otel.polarnova.io`, or
  - Join a shared Docker network and use `http://otel-collector:4318` (same host only).

## Failure domains

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Collector down | Ingest stops; apps buffer briefly then drop | Healthchecks + Uptime monitor + restart policy |
| ClickHouse down | Ingest + queries fail | Volume backups, disk alerts, resource limits |
| SigNoz UI down | Visibility lost; ingest may continue | Independent of collector health |
| Zookeeper down | ClickHouse coordination issues | Restart policy; restore ZK volume |

## Scaling path

Current: single-node Compose (startup / multi-product).

Next steps when ingest grows:

1. Increase ClickHouse disk + memory; tighten retention.
2. Run a gateway collector per product cluster; forward to central SigNoz.
3. Move to SigNoz Foundry / Kubernetes HA ClickHouse when a single node saturates.
