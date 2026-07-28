# PolarNova Observability — examples

Copy these bootstraps into each product repository. They are reference snippets, not a published package.

| Path | Runtime |
|------|---------|
| `python/otel_setup.py` | Python |
| `fastapi/main.py` | FastAPI |
| `django/manage_fragment.py` | Django |
| `nodejs/otel.js` | Node.js / Express |
| `nestjs/otel.ts` | NestJS |
| `nextjs/` | Next.js |
| `otel-smoke-trace.json` | curl smoke against OTLP HTTP |

Always set `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318` in production.
