# Application onboarding — PolarNova

Central OTLP collector service name: **`otel-collector`**  
Signals: traces, metrics, logs via OpenTelemetry.

## Private endpoints

| Path | Endpoint |
|------|----------|
| Same Coolify/Docker network | `http://otel-collector:4318` |
| Cross-VPS via Tailscale | `http://<obs-tailscale-ip>:4318` |
| Public HTTPS OTLP | **Not provided** (by design) |

> **Reaching the collector from a Coolify app (verified pattern — Vital AI).**
> The collector only lives on this stack's own resource network; apps on the
> shared `coolify` network can NOT resolve `otel-collector` by default. Join
> your app's telemetry-emitting services to this stack's network as an
> external network in your compose:
>
> ```yaml
> services:
>   backend:
>     networks:
>       - coolify
>       - observability
> networks:
>   coolify:
>     external: true
>   observability:
>     external: true
>     name: ${OBSERVABILITY_NETWORK:-<observability-stack-resource-uuid>}
> ```
>
> The stack's resource network name is its Coolify resource UUID (find it with
> `docker inspect <otel-collector-container> --format '{{json .NetworkSettings.Networks}}'`).
> OTLP ports stay unpublished — traffic never leaves the Docker host.

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://<endpoint-above>
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
```

## Resource attribute conventions

| Attribute | Rule |
|-----------|------|
| `service.name` | Canonical name from tables below |
| `service.namespace` | `polarnova` |
| `service.version` | Git SHA or semver |
| `deployment.environment.name` | `production` \| `staging` \| `development` |
| `deployment.environment` | Same value (compat with older SDKs) |
| `product` | `vital` \| `voxpilot` \| `foodiiz` \| `aidrop` \| `operator` |
| `component` | `api` \| `web` \| `worker` \| `scheduler` \| `websocket` \| … |
| `host.name` | Hostname / instance id |

Example:

```bash
OTEL_SERVICE_NAME=vital-backend
OTEL_SERVICE_NAMESPACE=polarnova
OTEL_RESOURCE_ATTRIBUTES=deployment.environment.name=production,deployment.environment=production,service.version=${GIT_SHA},product=vital,component=api
```

## Canonical service names

### Vital AI

| `service.name` | Role |
|----------------|------|
| `vital-backend` | Main API |
| `vital-websocket` | Realtime |
| `vital-celery-default` | Celery default queue |
| `vital-celery-ai` | Celery AI queue |
| `vital-celery-notifications` | Celery notifications |
| `vital-scheduler` | Beat / cron scheduler |

### VoxPilot

| `service.name` | Role |
|----------------|------|
| `voxpilot-api` | API |
| `voxpilot-voice-runtime` | Voice runtime |
| `voxpilot-worker` | Background worker |

### Foodiiz

| `service.name` | Role |
|----------------|------|
| `foodiiz-api` | API |
| `foodiiz-web` | Web |
| `foodiiz-worker` | Worker |

### AI Drop Cloud

| `service.name` | Role |
|----------------|------|
| `aidrop-api` | API |
| `aidrop-web` | Web |
| `aidrop-worker` | Worker |

### Operator

| `service.name` | Role |
|----------------|------|
| `operator-api` | API |
| `operator-web` | Web |
| `operator-worker` | Worker |

## SDKs

See `docs/instrumentation/` and `examples/` for Python, Django, FastAPI, Node, NestJS, Next.js, Celery/workers.

### Do not export

- Authorization headers, cookies, API keys
- PHI / patient content (Vital AI)
- Raw prompts / completions / audio
- Full SQL with bound PII (`db.statement` is redacted at collector as defense in depth)

## Checklist

1. Install OTel SDK / auto-instrumentation  
2. Set env vars + canonical `service.name`  
3. Deploy  
4. Confirm service appears in SigNoz within 2 minutes  
5. Add Uptime Kuma monitors for public health/SSL (private Kuma UI)  
6. Create error-rate / latency alerts in SigNoz  
