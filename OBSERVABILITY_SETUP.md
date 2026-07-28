# PolarNova Observability — Guía de configuración (ES)

Documento alineado con el Compose **actual** (SigNoz Foundry-style + Coolify).  
Para el checklist exacto de Coolify usa también [COOLIFY_DEPLOYMENT_GUIDE.md](COOLIFY_DEPLOYMENT_GUIDE.md).

---

## 1. Arquitectura

```
Apps PolarNova (OTel SDK)
        │  OTLP privado (Docker / Tailscale) :4317/:4318
        ▼
otel-collector  →  ClickHouse (+ clickhouse-keeper)
        ▲
postgres (metastore)     signoz UI ← https://observe.polarnova.io
uptime-kuma (sintético, privado al inicio)
```

Basado en la arquitectura oficial SigNoz Foundry (ClickHouse Keeper + PostgreSQL + migrator), no en el Compose legado pre-v0.130 (ZooKeeper/SQLite).

---

## 2. Contenedores / servicios

| Servicio Compose | Función |
|------------------|---------|
| `init-clickhouse` | One-shot: UDF histogramQuantile |
| `clickhouse-keeper` | Coordinación (reemplaza ZooKeeper) |
| `clickhouse` | Store de telemetría |
| `schema-migrator` | One-shot: migraciones SigNoz |
| `postgres` | Metastore SigNoz |
| `signoz` | UI/API pública |
| `otel-collector` | Ingesta OTLP **privada** |
| `uptime-kuma` | Monitoreo sintético |

---

## 3–10. Coolify (resumen ejecutivo)

1. **Opción:** Docker Compose  
2. **Rama:** `main`  
3. **Compose:** `docker-compose.yml`  
4. **Env:** `SIGNOZ_JWT_SECRET`, `POSTGRES_PASSWORD` (+ pins/límites de `.env.example`)  
5. **Dominio público:** servicio `signoz`  
6. **Puerto interno:** `8080` → en UI Coolify `https://observe.polarnova.io:8080`  
7. **Privado:** CH, Keeper, Postgres, OTLP, Kuma (fase 1)  
8. **Deploy** en Coolify  
9. **Salud:** `./scripts/health-check.sh` + login UI  
10. **Rollback:** restaurar tags/volumenes; nunca `down -v` sin backup  

Detalle: [COOLIFY_DEPLOYMENT_GUIDE.md](COOLIFY_DEPLOYMENT_GUIDE.md).

---

## Conexión de productos

Ver [APPLICATION_ONBOARDING.md](APPLICATION_ONBOARDING.md) para nombres canónicos:

- Vital: `vital-backend`, `vital-websocket`, `vital-celery-*`, `vital-scheduler`
- VoxPilot: `voxpilot-api`, `voxpilot-voice-runtime`, `voxpilot-worker`
- Foodiiz / AI Drop / Operator: tablas en ese documento

Endpoint OTLP:

```bash
# Misma red Coolify
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
# Otro VPS vía Tailscale
OTEL_EXPORTER_OTLP_ENDPOINT=http://100.x.x.x:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

**No** usar un dominio público OTLP.

---

## Variables por aplicación

```bash
OTEL_SERVICE_NAME=<canonical>
OTEL_SERVICE_NAMESPACE=polarnova
OTEL_RESOURCE_ATTRIBUTES=deployment.environment.name=production,deployment.environment=production,service.version=${GIT_SHA},product=<product>,component=<component>
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
```

SDKs e ejemplos: `docs/instrumentation/`, `examples/`.

---

## Buenas prácticas y mantenimiento

- Retención UI SigNoz: 7/15/7 días (traces/metrics/logs) en VPS compartido  
- Backups: [BACKUP_AND_RESTORE.md](BACKUP_AND_RESTORE.md)  
- Seguridad / Tailscale: [SECURITY.md](SECURITY.md)  
- Upgrade: backup → bump tags → redeploy → `./scripts/health-check.sh`  
