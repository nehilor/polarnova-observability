# AUDIT_REPORT — PolarNova Observability (pre-producción)

**Fecha:** 2026-07-28  
**Alcance:** repositorio completo `polarnova-observability`  
**Objetivo:** Coolify v4 · Docker Compose · Ubuntu VPS · Traefik Coolify · OTLP privado (Tailscale)  
**Veredicto:** **CONDITIONAL GO**

---

## Executive summary

La versión inicial del repositorio **no era apta para producción**: arquitectura SigNoz pre-Foundry (ZooKeeper + SQLite + tags `v0.128.0`), OTLP y Uptime publicados en host, documentación que empujaba `otel.polarnova.io` público, `container_name` rígidos, red Docker custom conflictiva con Coolify/Traefik, y configuración del collector **inválida** frente a `signoz-otel-collector:v0.144.6` (`service.telemetry.metrics.address`).

Se reescribió el stack alineado con **SigNoz Foundry** (docs oficiales post-v0.130): ClickHouse `25.12.5` + ClickHouse Keeper + PostgreSQL metastore + migrator `ready/bootstrap/sync/async` + SigNoz `v0.134.0` + collector `v0.144.6` + Uptime Kuma pinneado. OTLP queda privado; solo `signoz:8080` se expone vía Coolify.

**No se desplegó en Coolify ni se modificó DNS** (fuera de alcance).

---

## Critical findings (antes → después)

| ID | Severidad | Hallazgo | Estado |
|----|-----------|----------|--------|
| C1 | Critical | Compose legado ZooKeeper/SQLite vs Foundry actual | **Fixed** — Keeper + Postgres + CH 25.12.5 |
| C2 | Critical | OTLP `ports: 4317/4318` en `0.0.0.0` + docs `otel.polarnova.io` | **Fixed** — sin publish; Tailscale override opcional |
| C3 | Critical | Collector config inválida (`metrics.address`) | **Fixed** — validado con imagen real `v0.144.6` |
| C4 | Critical | Coolify: `ports` en UI + red custom | **Fixed** — `expose` en signoz; sin `networks:` custom |
| C5 | High | Secretos Postgres hardcodeables / JWT placeholder débil en docs | **Fixed** — `POSTGRES_PASSWORD` + `SIGNOZ_JWT_SECRET` required |
| C6 | High | Volume backup de CH en caliente presentado como válido | **Fixed** — scripts fallan si stack corre; docs de consistencia |
| C7 | High | `container_name` + healthcheck collector con wget dudoso | **Fixed** — sin container_name; sin HC frágil en collector |
| C8 | Medium | Docs/service names desalineados con canon pedido | **Fixed** — `APPLICATION_ONBOARDING.md` |
| C9 | Medium | cAdvisor privileged / exporters Prometheus | **Removed** del stack |
| C10 | Low | `exclude_from_hc` rompe `docker compose config` | **Removed** (label oneshot) |

---

## High / medium / low (residuales)

### Remaining risks (aceptados con CONDITIONAL GO)

| Riesgo | Mitigación manual requerida |
|--------|-----------------------------|
| OTLP cross-VPS | Configurar Tailscale + bind a IP Tailscale en Coolify Ports / override |
| Primer admin SigNoz/Kuma | Crear al primer boot; Kuma sin dominio hasta auth |
| Retención | Configurar en UI SigNoz (7/15/7) — env `RETENTION_*` es guía operativa |
| Stack E2E no levantado aquí | Validar `./scripts/health-check.sh` en el VPS tras Deploy |
| OpAMP warning deprecations | Upstream SigNoz; no bloquea arranque del collector |
| `attributes/redact` borra `db.statement` | Intencional (PHI); puede reducir debug SQL |
| Límites RAM compartidos | Ajustar tras observar presión real |

---

## Fixes applied (resumen técnico)

1. Reemplazo total de `docker-compose.yml` a arquitectura Foundry + Coolify.
2. Configs nuevas: `config/clickhouse/*.yaml`, `config/clickhouse-keeper/keeper.yaml`, collector endurecido.
3. Eliminados XML/ZooKeeper/SQLite/infra privileged.
4. Añadido `docker-compose.tailscale.yml` (bind obligatorio a `OTLP_BIND_HOST`).
5. Scripts de backup/restore/health reescritos (service names, consistencia).
6. Documentación requerida creada/actualizada; endpoints públicos OTLP eliminados de guías de app.

---

## Files changed (principales)

**Creados/actualizados:**  
`docker-compose.yml`, `docker-compose.tailscale.yml`, `.env.example`, `.gitignore`,  
`config/clickhouse/config.yaml`, `config/clickhouse/functions.yaml`, `config/clickhouse-keeper/keeper.yaml`,  
`config/otel/otel-collector-config.yaml`, `config/otel/opamp-config.yaml`,  
`scripts/*`, `SECURITY.md`, `BACKUP_AND_RESTORE.md`, `APPLICATION_ONBOARDING.md`,  
`COOLIFY_DEPLOYMENT_GUIDE.md`, `OBSERVABILITY_SETUP.md`, `README.md`, `AUDIT_REPORT.md`,  
`.github/workflows/validate-compose.yml`, docs alineados.

**Eliminados/obsoletos:**  
árbol ClickHouse XML legado, ZooKeeper, SQLite volume, perfil cAdvisor/node-exporter.

---

## Commands executed & validation results

| Comando | Resultado real |
|---------|----------------|
| `docker compose config --quiet` | **PASS** (exit 0) |
| `docker compose config --services` | **PASS** — lista 8 servicios esperados |
| Published ports en base compose | **PASS** — ninguno |
| Hub tags `signoz:v0.134.0`, `otel-collector:v0.144.6`, `clickhouse:25.12.5`, `keeper:25.12.5`, `postgres:16`, `uptime-kuma:1.23.16` | **PASS** (HTTP 200) |
| Override Tailscale sin `OTLP_BIND_HOST` | **PASS** (falla interpolación — esperado) |
| Override Tailscale con `OTLP_BIND_HOST=100.64.0.1` | **PASS** (exit 0) |
| ShellCheck (Docker `koalaman/shellcheck:stable`) sobre `scripts/*.sh` | **PASS** (exit 0 tras fix SC2034) |
| Collector `v0.144.6` carga config (timeout 10s) | **PASS** — `COLLECTOR_CONFIG_ACCEPTED` (extensiones + health_check arrancan; OpAMP no resuelve `signoz` fuera de compose — esperado) |
| Collector con `metrics.address` (antes del fix) | **FAIL documentado** — `invalid keys: address` |
| Secret scan (`sk_live`, `ghp_`, private keys, `password: signoz`) | **PASS** — sin coincidencias de alto riesgo |
| Referencias a ficheros de config montados | **PASS** |
| `docker compose up` E2E / Coolify deploy | **NO EJECUTADO** |

Fuentes oficiales consultadas:  
[SigNoz Docker/Foundry install](https://signoz.io/docs/install/docker/), Foundry example pours, [Coolify Compose docs](https://coolify.io/docs/knowledge-base/docker/compose), upgrade CH 25.12.5 notes.

---

## Go / No-Go

### **CONDITIONAL GO**

Apto para conectar el Git privado a Coolify y desplegar **después** de completar requisitos manuales:

1. Generar y cargar `SIGNOZ_JWT_SECRET` + `POSTGRES_PASSWORD` en Coolify.  
2. Dominio `https://observe.polarnova.io:8080` → servicio `signoz`.  
3. No publicar OTLP/CH/Postgres; Tailscale antes de apps remotas.  
4. Crear admin SigNoz; configurar retención UI.  
5. Uptime Kuma privado hasta auth; opcional `uptime.polarnova.io` después.  
6. Ejecutar `./scripts/health-check.sh` en el VPS post-deploy.  
7. Primer backup de volúmenes con stack parado antes de tráfico real.

**NO-GO** si se intenta exponer OTLP públicamente o usar el Compose legado anterior.

---

## Inventario post-auditoría (servicios)

| Service | Image (default pin) | Public | HC |
|---------|---------------------|--------|-----|
| init-clickhouse | clickhouse/clickhouse-server:25.12.5 | no | oneshot |
| clickhouse-keeper | clickhouse/clickhouse-keeper:25.12.5 | no | keeper-client |
| clickhouse | clickhouse/clickhouse-server:25.12.5 | no | /ping |
| schema-migrator | signoz/signoz-otel-collector:v0.144.6 | no | oneshot |
| postgres | postgres:16 | no | pg_isready |
| signoz | signoz/signoz:v0.134.0 | Coolify Traefik :8080 | /api/v1/health |
| otel-collector | signoz/signoz-otel-collector:v0.144.6 | no | :13133 (probe externo) |
| uptime-kuma | louislam/uptime-kuma:1.23.16 | no (fase 1) | extra/healthcheck |

**Volumes:** `pn-obs-clickhouse-data`, `pn-obs-clickhouse-keeper-data`, `pn-obs-clickhouse-user-scripts`, `pn-obs-postgres-data`, `pn-obs-uptime-kuma-data`.
