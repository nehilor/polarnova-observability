"""PolarNova OpenTelemetry bootstrap for Python services."""
from __future__ import annotations

import os

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


def setup_otel() -> None:
    service_name = os.getenv("OTEL_SERVICE_NAME", "python-service")
    environment = os.getenv("DEPLOYMENT_ENVIRONMENT", "production")
    version = os.getenv("SERVICE_VERSION", "0.0.0")

    resource = Resource.create(
        {
            "service.name": service_name,
            "service.namespace": os.getenv("OTEL_SERVICE_NAMESPACE", "polarnova"),
            "deployment.environment": environment,
            "service.version": version,
        }
    )

    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(tracer_provider)

    metric_reader = PeriodicExportingMetricReader(OTLPMetricExporter())
    meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
    from opentelemetry.metrics import set_meter_provider

    set_meter_provider(meter_provider)


if __name__ == "__main__":
    setup_otel()
    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span("polarnova-smoke-span") as span:
        span.set_attribute("polarnova.smoke", True)
        print("smoke span exported")
