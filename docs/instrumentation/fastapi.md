# FastAPI instrumentation

## Packages

```bash
pip install \
  "opentelemetry-distro" \
  "opentelemetry-exporter-otlp" \
  "opentelemetry-instrumentation-fastapi" \
  "opentelemetry-instrumentation-asgi" \
  "opentelemetry-instrumentation-httpx" \
  "opentelemetry-instrumentation-sqlalchemy" \
  "opentelemetry-instrumentation-redis" \
  "opentelemetry-instrumentation-logging"
opentelemetry-bootstrap -a install
```

## Run

```bash
export OTEL_SERVICE_NAME=foodiiz-api
export OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.polarnova.io
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

opentelemetry-instrument uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Manual (when you need control)

```python
from fastapi import FastAPI
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from examples_style_setup import setup_otel  # see examples/fastapi

setup_otel()
app = FastAPI()
FastAPIInstrumentor.instrument_app(app)
```

Full example: `examples/fastapi/main.py`.
