"""
Django: run with

  export OTEL_SERVICE_NAME=vital-ai-api
  export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
  export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
  opentelemetry-instrument gunicorn myproject.wsgi:application

Optional explicit setup in manage.py / asgi.py — prefer opentelemetry-instrument.
"""

# manage.py fragment
import os
import sys


def main():
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "myproject.settings")
    # If not using opentelemetry-instrument CLI, call setup_otel() here first.
    from django.core.management import execute_from_command_line

    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
