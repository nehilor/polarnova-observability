/**
 * Import this file first in main.ts:
 *   import './otel';
 *
 * Or: node --require ./dist/otel.js dist/main.js
 */
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';
import {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION,
} from '@opentelemetry/semantic-conventions';

const endpoint =
  process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318';

const sdk = new NodeSDK({
  resource: new Resource({
    [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'nestjs-service',
    [ATTR_SERVICE_VERSION]: process.env.SERVICE_VERSION || '0.0.0',
    'service.namespace': process.env.OTEL_SERVICE_NAMESPACE || 'polarnova',
    'deployment.environment':
      process.env.DEPLOYMENT_ENVIRONMENT || 'production',
  }),
  traceExporter: new OTLPTraceExporter({
    url: `${endpoint}/v1/traces`,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown().finally(() => process.exit(0));
});
