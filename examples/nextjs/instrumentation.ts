/**
 * Next.js instrumentation entry — place as instrumentation.ts and otel-node.ts
 * See docs/instrumentation/nextjs.md
 */
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await import('./otel-node');
  }
}
