# Next.js / React instrumentation

## Next.js (App Router)

Use OpenTelemetry via Next.js instrumentation hook.

### Packages

```bash
npm install @opentelemetry/api @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-http
```

### `instrumentation.ts` (project root / `src`)

```ts
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await import('./otel-node');
  }
}
```

Enable in `next.config.js`:

```js
module.exports = {
  experimental: {
    instrumentationHook: true, // older Next; newer versions enable by default
  },
};
```

See `examples/nextjs/`.

### Environment

```bash
OTEL_SERVICE_NAME=vital-ai-web
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

## Browser / React SPA

For pure client SPAs, prefer:

1. Server-side tracing on BFF/API (primary), and/or
2. OpenTelemetry Browser SDK exporting to OTLP HTTP **with CORS** allowed on the collector (already permits `*.polarnova.io`).

Do not put secrets in browser exporters. Prefer a same-origin collector proxy if you expose OTLP publicly.
