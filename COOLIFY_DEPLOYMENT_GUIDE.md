# Guía de despliegue en Coolify (Español)

Plataforma de observabilidad PolarNova — **SigNoz + ClickHouse + OpenTelemetry Collector + Uptime Kuma**.

## 1. Opción a seleccionar en Coolify

1. Abrir Coolify v4.
2. **+ New Resource** → **Docker Compose** (build pack / tipo Docker Compose).
3. Conectar el **repositorio Git privado** de este proyecto.
4. No usar “Dockerfile” ni “Static”; debe ser **Compose**.

## 2. Rama Git

Usar la rama: **`main`**

## 3. Ruta del Compose

- Base directory: `/` (raíz del repo)
- Compose file: **`docker-compose.yml`**
- No activar `docker-compose.tailscale.yml` en Coolify salvo que controles el comando compose y hayas definido `OTLP_BIND_HOST`.

## 4. Variables de entorno a crear en Coolify

Copiar desde `.env.example`. **Obligatorias** (sustituir placeholders):

| Variable | Notas |
|----------|--------|
| `SIGNOZ_JWT_SECRET` | `openssl rand -base64 48` |
| `POSTGRES_PASSWORD` | `openssl rand -base64 32` |

Recomendadas (pueden dejarse los defaults del ejemplo):

- `IMAGE_SIGNOZ_TAG=v0.134.0` (**no** uses `SIGNOZ_VERSION` — colisiona con SigNoz)
- `IMAGE_OTELCOL_TAG=v0.144.6`
- `IMAGE_CLICKHOUSE_TAG=25.12.5`
- `IMAGE_POSTGRES_TAG=16`
- `IMAGE_UPTIME_KUMA_TAG=1.23.16`
- `POSTGRES_DB=signoz`
- `POSTGRES_USER=signoz`
- Límites de CPU/RAM del `.env.example`
- `DEPLOYMENT_ENVIRONMENT=production`

**No** publicar secretos reales en Git.

## 5. Servicio que recibe `observe.polarnova.io`

Servicio Compose: **`signoz`**

## 6. Puerto interno de ese servicio

Puerto del contenedor: **`8080`**

En Coolify, al asignar el dominio al servicio `signoz`, indicar:

```text
https://observe.polarnova.io:8080
```

(El `:8080` dice a Traefik a qué puerto **interno** enrutar; públicamente sigue siendo 443.)

## 7. Puertos que deben permanecer privados

| Puerto / servicio | Exposición pública |
|-------------------|-------------------|
| ClickHouse `8123` / `9000` | **Prohibido** |
| ClickHouse Keeper `9181` | **Prohibido** |
| Postgres `5432` | **Prohibido** |
| OTLP `4317` / `4318` | **Prohibido en 0.0.0.0** — solo red Docker y/o IP Tailscale |
| Uptime Kuma `3001` | Privado en el primer despliegue (sin dominio) |
| Collector health `13133` | Privado |

**No** crear dominio `otel.polarnova.io` en esta fase.

## 8. Cómo desplegar

1. Guardar variables de entorno.
2. Asignar dominio al servicio **`signoz`**: `https://observe.polarnova.io:8080`.
3. Dejar **sin dominio** `otel-collector` y `uptime-kuma`.
4. Asegurar disco SSD suficiente (ClickHouse).
5. Pulsar **Deploy**.
6. Esperar: `init-clickhouse` → `clickhouse-keeper` → `clickhouse` → `schema-migrator` → `postgres`/`signoz`/`otel-collector`/`uptime-kuma`.
7. Abrir `https://observe.polarnova.io` y **crear el usuario admin** de inmediato.
8. SigNoz → **Settings → Retention**: traces 7d, metrics 15d, logs 7d (ajustable).
9. Acceder a Uptime Kuma solo por red privada / tunnel; crear admin antes de exponer `uptime.polarnova.io`.

### Ingesta OTLP desde otros VPS (Tailscale)

1. Instalar Tailscale en el VPS de observabilidad y en los VPS de apps.
2. En Coolify (o con `docker-compose.tailscale.yml`), publicar `4317`/`4318` **solo** en la IP Tailscale del host (`OTLP_BIND_HOST`), nunca `0.0.0.0`.
3. En cada app: `OTEL_EXPORTER_OTLP_ENDPOINT=http://<tailscale-ip>:4318`.

Apps en el mismo stack/red Coolify: `http://otel-collector:4318`.

## 9. Cómo verificar salud

En el servidor (SSH):

```bash
cd /ruta/del/repo   # o docker compose -p <proyecto> desde el directorio Coolify
docker compose ps
./scripts/health-check.sh
```

Comprobaciones esperadas:

- `signoz` healthy → `/api/v1/health`
- `clickhouse` ping Ok
- `postgres` pg_isready
- `clickhouse-keeper` responde
- `otel-collector` health en `:13133`
- UI: login en `https://observe.polarnova.io`

## 10. Cómo hacer rollback seguro

1. **No** borrar volúmenes (`docker compose down -v` destruye datos).
2. Antes de upgrades: `./scripts/backup-all.sh` y, con stack parado, `./scripts/backup-volumes.sh`.
3. Rollback de imágenes: restaurar tags anteriores en env (`IMAGE_SIGNOZ_TAG`, etc.) → Redeploy.
4. Rollback de datos: `docker compose stop` → `./scripts/restore-volume.sh …` → `docker compose up -d`.
5. Verificar con `./scripts/health-check.sh` y login UI.

Ver también: [BACKUP_AND_RESTORE.md](BACKUP_AND_RESTORE.md), [SECURITY.md](SECURITY.md).

## Incidente conocido: bind mounts convertidos en directorios

Si Coolify crea rutas como `config/.../keeper.yaml` como **directorios vacíos**, ClickHouse Keeper hace segfault (exit 139).

Causa: Docker/Coolify materializa el path del bind mount como directorio cuando el fichero no existe en el checkout desplegado.

Mitigación:
1. Asegurar que los YAML de `config/` están en el commit desplegado.
2. Tras un deploy roto: borrar los stubs-directorio, copiar los ficheros reales y `docker compose up -d --force-recreate`.
3. Nunca usar variables de entorno `SIGNOZ_VERSION` (colisiona con la config interna de SigNoz). Usar `IMAGE_SIGNOZ_TAG`.
