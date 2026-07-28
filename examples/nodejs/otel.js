'use strict';

/**
 * Preload with:
 *   NODE_OPTIONS="--require ./otel.js" node server.js
 *
 * Env:
 *   OTEL_SERVICE_NAME=aidrop-api
 *   OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
 *   OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
 */

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION,
} = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({
    [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'node-service',
    [ATTR_SERVICE_VERSION]: process.env.SERVICE_VERSION || '0.0.0',
    'service.namespace': process.env.OTEL_SERVICE_NAMESPACE || 'polarnova',
    'deployment.environment':
      process.env.DEPLOYMENT_ENVIRONMENT || 'production',
  }),
  traceExporter: new OTLPTraceExporter({
    url:
      (process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318') +
      '/v1/traces',
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': { enabled: false },
    }),
  ],
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown().finally(() => process.exit(0));
});
