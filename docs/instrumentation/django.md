# Django instrumentation

## Packages

```bash
pip install \
  opentelemetry-distro \
  opentelemetry-exporter-otlp \
  opentelemetry-instrumentation-django \
  opentelemetry-instrumentation-psycopg2 \
  opentelemetry-instrumentation-redis \
  opentelemetry-instrumentation-celery \
  opentelemetry-instrumentation-logging
opentelemetry-bootstrap -a install
```

## Run

```bash
export OTEL_SERVICE_NAME=vital-ai-api   # example
export OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.polarnova.io
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

opentelemetry-instrument gunicorn myproject.wsgi:application
```

## settings.py tips

- Ensure `DJANGO_SETTINGS_MODULE` is set before instrumentation.
- Add request ID middleware if you correlate logs manually.
- Do not log Authorization headers.

## Celery

Instrument workers with the same env vars:

```bash
opentelemetry-instrument celery -A myproject worker -l INFO
```

See [workers.md](workers.md).
