"""Minimal FastAPI app with OpenTelemetry."""
from fastapi import FastAPI

# Prefer auto-instrumentation in production:
#   opentelemetry-instrument uvicorn examples.fastapi.main:app
# This file shows manual wiring for clarity.

from otel_bootstrap import setup_otel  # copy otel_setup.py beside your app as otel_bootstrap.py

setup_otel()

from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

app = FastAPI(title="PolarNova example")
FastAPIInstrumentor.instrument_app(app)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/hello")
def hello():
    return {"message": "hello from instrumented fastapi"}
