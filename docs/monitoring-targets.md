# Monitoring targets

Central catalogue of what PolarNova Observability should watch.

## Applications (APM via OpenTelemetry → SigNoz)

| Target | Traces | Metrics | Logs | Errors | Uptime HTTP | SSL |
|--------|--------|---------|------|--------|-------------|-----|
| Vital AI | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| VoxPilot | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Foodiiz | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| AI Drop Cloud | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Operator | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Future products | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## Infrastructure

| Target | How |
|--------|-----|
| Host machine | Node Exporter (`--profile infra`) + Uptime ping |
| Docker / Coolify containers | cAdvisor (`--profile infra`) |
| Coolify dashboard | Uptime HTTP(s) |
| AI Server | OTel SDK on services + host metrics + HTTP health |
| Database Server | TCP check (Uptime) + postgres exporter (optional) + app spans |
| Mail Server | SMTP/IMAP TCP + optional blackbox |
| PostgreSQL | App instrumentation + TCP `:5432` + optional `postgres_exporter` |
| Redis | App instrumentation + TCP `:6379` + optional `redis_exporter` |

## Synthetic (Uptime Kuma)

| Check | Type |
|-------|------|
| Product health endpoints | HTTP(s) |
| observe / uptime / otel | HTTP(s) |
| SMTP `587` / `465` | TCP |
| IMAP `993` | TCP |
| Public certificates | SSL Certificate (alert &lt; 14 days) |
| Keyword checks | HTTP keyword (e.g. `"status":"ok"`) |

## SigNoz alert suggestions

| Alert | Signal | Condition |
|-------|--------|-----------|
| High error rate | traces / metrics | error ratio &gt; 5% for 5m |
| Latency regression | spanmetrics | p95 &gt; SLO for 10m |
| Collector down | uptime / metrics | scrape / HTTP fail |
| Disk pressure | host metrics | filesystem &gt; 85% |
| Log spike | logs | ERROR count surge |

Wire notifications to Slack/Telegram from both SigNoz and Uptime Kuma.
