# Architecture (current)

SigNoz **Foundry-aligned** single-node Compose for Coolify:

```
Apps ──OTLP (private)──▶ otel-collector ──▶ clickhouse ◀── signoz
                              │                 ▲
                              │          clickhouse-keeper
                         postgres (metastore)
uptime-kuma (synthetic, separate)
```

## Why these components

| Component | Source of truth |
|-----------|-----------------|
| ClickHouse Keeper | SigNoz Foundry default telemetry keeper |
| PostgreSQL metastore | SigNoz Foundry default (replaces SQLite) |
| Schema migrator | `migrate ready/bootstrap/sync/async` |
| No Grafana/Loki/Jaeger | SigNoz covers UI/query |

## Coolify networking

- No custom `networks:` in compose (Coolify + Traefik attach their network).
- Public UI via `expose: "8080"` on `signoz` + domain in Coolify UI.
- OTLP not published on `0.0.0.0`.

## Scaling path

1. Tighten retention / disk  
2. Gateway collectors per product cluster → central `otel-collector`  
3. Foundry/K8s HA when single node saturates  
