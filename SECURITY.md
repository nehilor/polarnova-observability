# Security Policy — PolarNova Observability

## Threat model (summary)

| Asset | Risk if exposed |
|-------|-----------------|
| SigNoz UI | Telemetry of all products (incl. healthcare) |
| OTLP ingestion | Spoofed/poisoned telemetry; resource exhaustion |
| ClickHouse | Full telemetry dump |
| Postgres metastore | Users, dashboards, alert config |
| Uptime Kuma | Internal monitor topology |

## Hard requirements

1. **HTTPS** for `observe.polarnova.io` terminates at Coolify Traefik — not inside this Compose.
2. **No public OTLP.** Do not assign a Coolify domain to `otel-collector`. Do not publish `0.0.0.0:4317/4318`.
3. **No public ClickHouse / Keeper / Postgres.** No host port mappings.
4. **Secrets only in Coolify env / `.env` (gitignored).** Placeholders live in `.env.example`.
5. **Uptime Kuma stays private** until admin account + optional `uptime.polarnova.io` are ready.
6. **SigNoz requires first-login admin** — create immediately after first deploy; enable strong password / SSO later if available.

## Private telemetry path (Tailscale)

Recommended pattern for apps on other VPS:

```
App VPS ──Tailscale──▶ Observability VPS Tailscale IP:4318
                              │
                              └── docker publish bound to Tailscale IP only
                                  (docker-compose.tailscale.yml or Coolify Ports UI)
```

Example app env:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://100.x.x.x:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

Same Coolify host / Docker network:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

Never use `https://otel.polarnova.io` unless you intentionally build a private authenticated gateway (not in this repo).

## Compose controls

- `security_opt: no-new-privileges:true` on services
- Read-only mounts for config files
- Log rotation (`max-size` / `max-file`)
- Resource limits on every long-running service
- Collector redacts common auth / secret / prompt attribute keys

## Forbidden

- Committing `.env`, `*.secret`, backup archives with data
- Default passwords (`signoz`/`signoz`) in production
- Grafana / Loki / Jaeger / GlitchTip / public Prometheus
- Privileged exporters (cAdvisor) in this stack

## Reporting

Internal PolarNova platform team. Rotate `SIGNOZ_JWT_SECRET` and `POSTGRES_PASSWORD` if leaked.
