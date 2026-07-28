# NestJS instrumentation

## Packages

```bash
npm install --save \
  @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-http \
  @opentelemetry/resources \
  @opentelemetry/semantic-conventions
```

## Bootstrap order

NestJS must load OpenTelemetry **before** `NestFactory.create`.

`package.json`:

```json
{
  "scripts": {
    "start:prod": "node --require ./dist/otel.js dist/main.js"
  }
}
```

Or in `main.ts` (first lines):

```ts
import './otel';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(process.env.PORT || 3000);
}
bootstrap();
```

See `examples/nestjs/otel.ts`.

## Environment

```bash
OTEL_SERVICE_NAME=voxpilot-api
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.namespace=polarnova
```
