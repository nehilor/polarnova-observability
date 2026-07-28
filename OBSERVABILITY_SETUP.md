# PolarNova Observability — Guía de configuración

Documento operativo en español para desplegar y conectar la plataforma centralizada de observabilidad de PolarNova.

**Audiencia:** DevOps, Platform, SRE y equipos de producto (Vital AI, VoxPilot, Foodiiz, AI Drop Cloud, Operator).

**Stack:** SigNoz · OpenTelemetry Collector · ClickHouse · Uptime Kuma  
**Despliegue:** Docker Compose en Coolify  
**Dominios:** `observe.polarnova.io` · `uptime.polarnova.io` · `otel.polarnova.io`

---

## 1. Visión de la arquitectura

La plataforma es el **único punto de observabilidad** para todos los productos actuales y futuros de PolarNova.

```
Aplicaciones PolarNova (SDK OpenTelemetry)
        │  OTLP HTTP :4318 / gRPC :4317
        ▼
otel.polarnova.io  →  OpenTelemetry Collector
        │  batch, filtros, spanmetrics, enrichment
        ▼
ClickHouse (+ Zookeeper)   ← almacenamiento de traces, metrics, logs
        ▲
        │  consultas
observe.polarnova.io  →  SigNoz (UI, alertas, dashboards, excepciones)

uptime.polarnova.io  →  Uptime Kuma (HTTP, SSL, TCP, SMTP/IMAP, health checks)
```

### Qué cubre

| Capacidad | Componente |
|-----------|------------|
| Application Monitoring (APM) | SigNoz |
| Distributed Tracing | SigNoz + OTel |
| Metrics | SigNoz + OTel |
| Logs | SigNoz + OTel |
| Error Tracking | SigNoz (exceptions / error spans) |
| Infrastructure Monitoring | Node Exporter + cAdvisor (perfil `infra`) |
| Docker Monitoring | cAdvisor |
| Database / Redis | spans de app + checks TCP en Uptime Kuma |
| SSL / HTTP / Health | Uptime Kuma |
| Escalabilidad futura | Collectors gateway + retención + (luego) HA |

**No se instala** Grafana, Loki ni Jaeger: SigNoz ya cubre esas funciones.

---

## 2. Qué hace cada contenedor

| Contenedor | Imagen | Función |
|------------|--------|---------|
| `pn-obs-init-clickhouse` | clickhouse-server | Descarga el UDF `histogramQuantile` (APM) y termina |
| `pn-obs-zookeeper` | signoz/zookeeper | Coordinación de ClickHouse |
| `pn-obs-clickhouse` | clickhouse-server | Base columnar de telemetría |
| `pn-obs-schema-migrator` | signoz-otel-collector | Crea/actualiza esquemas SigNoz y sale |
| `pn-obs-signoz` | signoz/signoz | UI, API, alertas, usuarios, dashboards |
| `pn-obs-otel-collector` | signoz-otel-collector | Ingesta OTLP → ClickHouse |
| `pn-obs-uptime-kuma` | louislam/uptime-kuma | Monitoreo sintético |
| `pn-obs-node-exporter` | (opcional, profile `infra`) | Métricas del host |
| `pn-obs-cadvisor` | (opcional, profile `infra`) | Métricas de contenedores |

Red interna: `polarnova-observability`.  
ClickHouse y Zookeeper **no** publican puertos al exterior.

---

## 3. Cómo desplegarlo en Coolify

1. En Coolify: **New Resource → Docker Compose**.
2. Conectar el repositorio Git `polarnova-observability` (rama `main`).
3. Compose file: `docker-compose.yml` (raíz del repo).
4. Copiar variables desde `.env.example` a las Environment Variables de Coolify.
5. Generar y definir `SIGNOZ_JWT_SECRET` (obligatorio):

   ```bash
   openssl rand -base64 48
   ```

6. Asignar dominios (tabla siguiente) con HTTPS (Let's Encrypt).
7. Asegurar disco SSD amplio (ClickHouse crece con retención).
8. **Deploy**.
9. Primera visita a SigNoz y Uptime Kuma: crear usuarios admin.
10. Configurar retención en SigNoz (**Settings → Retention**).
11. Crear monitores en Uptime Kuma según `config/uptime-kuma/README.md`.

Validación en el host:

```bash
./scripts/health-check.sh
```

Detalle adicional: [docs/deployment-coolify.md](docs/deployment-coolify.md).

---

## 4. Subdominios requeridos

| Subdominio | Servicio Coolify | Puerto contenedor | Uso |
|------------|------------------|-------------------|-----|
| **observe.polarnova.io** | `signoz` | `8080` | UI de observabilidad |
| **uptime.polarnova.io** | `uptime-kuma` | `3001` | Health / SSL / TCP |
| **otel.polarnova.io** | `otel-collector` | `4318` | Ingesta OTLP HTTP (recomendado) |

### Notas de red

- **OTLP HTTP** detrás de HTTPS de Coolify es el camino por defecto para todas las apps.
- **OTLP gRPC (`4317`)** requiere proxy TCP o publicación controlada del puerto; úsalo solo si un SDK lo exige.
- No exponer `8123`/`9000` (ClickHouse) ni Zookeeper.

### Variables públicas de referencia

```bash
PUBLIC_SIGNOZ_URL=https://observe.polarnova.io
PUBLIC_UPTIME_URL=https://uptime.polarnova.io
PUBLIC_OTLP_HTTP_ENDPOINT=https://otel.polarnova.io
PUBLIC_OTLP_GRPC_ENDPOINT=otel.polarnova.io:4317
```

---

## 5. Cómo debe conectarse cada aplicación existente

Regla común para **todas**:

```bash
OTEL_SERVICE_NAMESPACE=polarnova
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.polarnova.io
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.version=<GIT_SHA>
```

### Vital AI (Healthcare AI Platform)

| Componente | `OTEL_SERVICE_NAME` | Notas |
|------------|---------------------|-------|
| API | `vital-ai-api` | Django/FastAPI según el servicio |
| Workers / Celery | `vital-ai-worker` | Misma endpoint OTLP |
| Frontend | `vital-ai-web` | Next.js `instrumentation.ts` |

Monitores Uptime: health HTTP + SSL del dominio público.  
En SigNoz: filtrar por `service.namespace=polarnova` y `service.name` con prefijo `vital-ai-`.

### VoxPilot (AI Voice Platform)

| Componente | `OTEL_SERVICE_NAME` |
|------------|---------------------|
| API | `voxpilot-api` |
| Voice / realtime | `voxpilot-voice` |
| Workers | `voxpilot-worker` |

Instrumentar llamadas a proveedores de voz como spans hijos; no registrar audio ni PII en atributos.

### Foodiiz (Restaurant AI Platform)

| Componente | `OTEL_SERVICE_NAME` |
|------------|---------------------|
| API | `foodiiz-api` |
| Web | `foodiiz-web` |
| Workers | `foodiiz-worker` |

Incluir `http.route` y atributos de tenant **sin** datos personales de comensales.

### AI Drop Cloud (AI Commerce Platform)

| Componente | `OTEL_SERVICE_NAME` |
|------------|---------------------|
| API | `aidrop-api` |
| Web | `aidrop-web` |
| Workers | `aidrop-worker` |

Trazar checkout y jobs de catálogo; muestrear tráfico alto (`OTEL_TRACES_SAMPLER_ARG=0.1`–`0.25`).

### Operator (Internal Platform)

| Componente | `OTEL_SERVICE_NAME` |
|------------|---------------------|
| API | `operator-api` |
| Web | `operator-web` |
| Jobs | `operator-jobs` |

Puede usar red Docker interna si corre en el mismo host:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://pn-obs-otel-collector:4318
```

### Productos futuros

1. Elegir `OTEL_SERVICE_NAME` = `<producto>-<componente>`.
2. Instalar SDK (sección 7–8).
3. Desplegar con las env vars de la sección 6.
4. Añadir monitores en Uptime Kuma.
5. Crear alertas base en SigNoz (error rate, latencia p95).

---

## 6. Variables de entorno exactas por aplicación

Copiar este bloque en Coolify / `.env` de **cada** servicio de producto:

```bash
# --- Identidad ---
OTEL_SERVICE_NAME=<producto>-<componente>
OTEL_SERVICE_NAMESPACE=polarnova
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.version=${GIT_SHA},service.instance.id=${HOSTNAME}

# --- Exportador (producción PolarNova) ---
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.polarnova.io
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

# --- Señales ---
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp

# --- Muestreo recomendado en alto tráfico ---
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.25
```

### Valores sugeridos por producto

| Producto | Ejemplos `OTEL_SERVICE_NAME` |
|----------|------------------------------|
| Vital AI | `vital-ai-api`, `vital-ai-worker`, `vital-ai-web` |
| VoxPilot | `voxpilot-api`, `voxpilot-voice`, `voxpilot-worker` |
| Foodiiz | `foodiiz-api`, `foodiiz-web`, `foodiiz-worker` |
| AI Drop Cloud | `aidrop-api`, `aidrop-web`, `aidrop-worker` |
| Operator | `operator-api`, `operator-web`, `operator-jobs` |

### Variables del stack de observabilidad (servidor Coolify)

Ver `.env.example`. Las críticas:

| Variable | Obligatoria | Descripción |
|----------|-------------|-------------|
| `SIGNOZ_JWT_SECRET` | Sí | Secreto JWT de sesiones SigNoz |
| `SIGNOZ_VERSION` | Sí | Tag de imagen SigNoz |
| `OTELCOL_VERSION` | Sí | Tag del collector |
| `CLICKHOUSE_VERSION` | Sí | Tag ClickHouse |
| `*_HOST_PORT` | Según host | Puertos publicados |
| `*_MEMORY_LIMIT` | Recomendado | Límites de recursos |

---

## 7. SDK OpenTelemetry a instalar por tipo de proyecto

### Python / Django / FastAPI / Celery

```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install
```

Paquetes frecuentes adicionales:

```bash
pip install \
  opentelemetry-instrumentation-django \
  opentelemetry-instrumentation-fastapi \
  opentelemetry-instrumentation-asgi \
  opentelemetry-instrumentation-celery \
  opentelemetry-instrumentation-psycopg2 \
  opentelemetry-instrumentation-sqlalchemy \
  opentelemetry-instrumentation-redis \
  opentelemetry-instrumentation-httpx \
  opentelemetry-instrumentation-logging
```

Arranque:

```bash
opentelemetry-instrument <tu-comando>
```

### Node.js / Express / NestJS / workers

```bash
npm install --save \
  @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-http \
  @opentelemetry/exporter-metrics-otlp-http \
  @opentelemetry/resources \
  @opentelemetry/semantic-conventions
```

Arranque:

```bash
NODE_OPTIONS="--require ./otel.js" node dist/main.js
```

### Next.js

```bash
npm install @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-http \
  @opentelemetry/resources \
  @opentelemetry/semantic-conventions
```

Usar `instrumentation.ts` (ver ejemplos).

### React SPA (solo browser)

Preferir trazas en BFF/API. Si se instrumenta el browser, exportar a OTLP HTTP con CORS (el collector ya permite `*.polarnova.io`) y **nunca** secretos en el cliente.

---

## 8. Ejemplos de inicialización

### Python (manual)

```python
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

resource = Resource.create({
    "service.name": "vital-ai-api",
    "service.namespace": "polarnova",
    "deployment.environment": "production",
})
provider = TracerProvider(resource=resource)
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(provider)
```

Archivo completo: `examples/python/otel_setup.py`.

### FastAPI

```bash
export OTEL_SERVICE_NAME=foodiiz-api
opentelemetry-instrument uvicorn app.main:app --host 0.0.0.0 --port 8000
```

O instrumentación manual: `examples/fastapi/main.py`.

### Django

```bash
export OTEL_SERVICE_NAME=vital-ai-api
export OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.polarnova.io
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
opentelemetry-instrument gunicorn myproject.wsgi:application
```

### Node.js

```js
// otel.js — precargar con NODE_OPTIONS=--require ./otel.js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: `${process.env.OTEL_EXPORTER_OTLP_ENDPOINT}/v1/traces`,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

Ver `examples/nodejs/otel.js`.

### NestJS

```ts
// Primera línea de main.ts
import './otel';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(process.env.PORT || 3000);
}
bootstrap();
```

Ver `examples/nestjs/otel.ts`.

---

## 9. Buenas prácticas

1. **Un `service.name` por proceso** (`api`, `worker`, `web` separados).
2. **Instrumentar al arrancar** el proceso, antes del framework cuando sea posible.
3. **Propagar contexto** en HTTP, colas y gRPC (traceparent).
4. **No enviar secretos ni PII** en atributos de spans ni logs (salud, voz, pagos).
5. **Muestrear** tráfico alto; mantener errores visibles.
6. **Versionar** con `service.version` = Git SHA o semver.
7. **Health checks** en `/health` (el collector filtra rutas comunes).
8. **Alertas** en SigNoz + notificaciones en Uptime Kuma (Slack/Telegram).
9. **Retención** acorde al disco (p. ej. traces 7–15d, metrics 30d, logs 7–15d).
10. **Backups** antes de cada upgrade (`./scripts/backup-all.sh --volumes`).

---

## 10. Procedimientos de mantenimiento

### Salud diaria / semanal

```bash
./scripts/health-check.sh
docker compose ps
df -h
```

Revisar alertas en SigNoz y Uptime Kuma.

### Backup

```bash
# Diario: config + dump lógico ClickHouse
./scripts/backup-all.sh

# Semanal o pre-upgrade: incluye volúmenes Docker
./scripts/backup-all.sh --volumes
```

Copiar `backups/` fuera del servidor. Guía: [docs/backups.md](docs/backups.md).

### Restore

```bash
./scripts/restore-clickhouse.sh backups/clickhouse/<timestamp>
./scripts/restore-volume.sh pn-obs-signoz-data backups/volumes/<ts>/pn-obs-signoz-data.tar.gz
```

### Upgrade

1. Backup completo.
2. Cambiar tags en `.env` / Coolify.
3. `./scripts/upgrade.sh` o Redeploy en Coolify.
4. Verificar UI + traza de prueba.
5. Leer [docs/upgrading.md](docs/upgrading.md).

### Añadir un producto nuevo

1. Instrumentar con OTel (secciones 6–8).
2. Desplegar y confirmar datos en `https://observe.polarnova.io`.
3. Crear monitores HTTP/SSL en Uptime Kuma.
4. Definir SLOs y alertas.
5. Documentar `OTEL_SERVICE_NAME` en el README del producto.

### Runbooks de incidente

Ver [docs/runbooks/incidents.md](docs/runbooks/incidents.md) (ingesta caída, disco lleno, UI caída, restore).

---

## Referencias rápidas

| Recurso | Ruta |
|---------|------|
| README principal | [README.md](README.md) |
| Compose | [docker-compose.yml](docker-compose.yml) |
| Variables | [.env.example](.env.example) |
| Onboarding EN | [docs/onboarding.md](docs/onboarding.md) |
| Coolify | [docs/deployment-coolify.md](docs/deployment-coolify.md) |
| Ejemplos SDK | [examples/](examples/) |

---

*PolarNova Platform Engineering — Observabilidad centralizada, self-hosted y production-grade.*
