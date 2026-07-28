# Application onboarding

How any PolarNova product joins the observability platform.

## Checklist

1. Choose service name: `<product>-<component>` (e.g. `vital-ai-api`, `voxpilot-worker`).
2. Set namespace `polarnova` and environment `production|staging`.
3. Install OpenTelemetry SDK for the runtime (see `docs/instrumentation/`).
4. Configure OTLP endpoint env vars (below).
5. Deploy and confirm traces appear in SigNoz within 2 minutes.
6. Add Uptime Kuma HTTP + SSL monitors for public URLs.
7. Create SigNoz alerts (error rate, latency p95, log ERROR rate).

## Required environment variables (every app)

```bash
# Identity
OTEL_SERVICE_NAME=my-service
OTEL_SERVICE_NAMESPACE=polarnova
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.version=${GIT_SHA},service.instance.id=${HOSTNAME}

# Exporter
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.polarnova.io
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

# Signals
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp

# Optional sampling (production)
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.25
```

Same-host Docker alternative:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://pn-obs-otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

## Product service name map

| Product | Suggested `OTEL_SERVICE_NAME` values |
|---------|--------------------------------------|
| Vital AI | `vital-ai-api`, `vital-ai-worker`, `vital-ai-web` |
| VoxPilot | `voxpilot-api`, `voxpilot-voice`, `voxpilot-worker` |
| Foodiiz | `foodiiz-api`, `foodiiz-web`, `foodiiz-worker` |
| AI Drop Cloud | `aidrop-api`, `aidrop-web`, `aidrop-worker` |
| Operator | `operator-api`, `operator-web`, `operator-jobs` |

## Framework guides

| Stack | Doc |
|-------|-----|
| Python (generic) | [instrumentation/python.md](instrumentation/python.md) |
| Django | [instrumentation/django.md](instrumentation/django.md) |
| FastAPI | [instrumentation/fastapi.md](instrumentation/fastapi.md) |
| Node.js / Express | [instrumentation/nodejs.md](instrumentation/nodejs.md) |
| NestJS | [instrumentation/nestjs.md](instrumentation/nestjs.md) |
| Next.js / React | [instrumentation/nextjs.md](instrumentation/nextjs.md) |
| Celery / workers / cron | [instrumentation/workers.md](instrumentation/workers.md) |

## Best practices

- Instrument **at process start** (before importing app code when using auto-instrumentation).
- Propagate context across HTTP, queues, and gRPC.
- Use consistent `service.version` (Git SHA or semver).
- Sample high-traffic traces; keep errors always sampled when possible.
- Do not send secrets/PII in span attributes or log bodies.
- Prefer OTLP HTTP behind Coolify TLS unless you operate gRPC TCP passthrough.
- Add a `/health` endpoint excluded from noise (collector already filters common routes).
