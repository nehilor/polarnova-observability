# Workers, Celery, background jobs, cron

Background work must share the same OTLP endpoint and **propagate trace context** from producers (HTTP handlers, publishers).

## Universal env

```bash
OTEL_SERVICE_NAME=foodiiz-worker
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.polarnova.io
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.namespace=polarnova
```

## Celery

```bash
pip install opentelemetry-instrumentation-celery
opentelemetry-instrument celery -A myproject worker -l INFO
```

Ensure the web process that enqueues tasks is also instrumented so `traceparent` is injected into task headers.

## Node workers (Bull / BullMQ / Agenda)

Use `@opentelemetry/auto-instrumentations-node` with preload (`NODE_OPTIONS=--require ./otel.js`).  
Instrument Redis connections used by the queue.

## Cron / one-shot jobs

Wrap the entrypoint:

```bash
opentelemetry-instrument python jobs/nightly_report.py
# or
node --require ./otel.js jobs/nightly.js
```

Create a root span for the job name so failures show as a single trace in SigNoz.

## Best practices

- One `service.name` per worker pool.
- Attribute `messaging.system`, queue name, and job id.
- Capture exceptions with `span.recordException(err)`.
- Avoid linking high-cardinality job payloads as attributes.
