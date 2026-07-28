# Deploying on Coolify

## Prerequisites

- Coolify instance with Docker Compose support
- Domain DNS for:
  - `observe.polarnova.io`
  - `uptime.polarnova.io`
  - `otel.polarnova.io`
- Host with ≥ 16 GB RAM recommended
- Git access to this repository

## Step-by-step

### 1. Create resource

Coolify → **New Resource** → **Docker Compose** → connect Git repo `polarnova-observability`.

- Base directory: `/`
- Compose file: `docker-compose.yml`
- Branch: `main`

### 2. Environment variables

Paste from `.env.example`, then:

```bash
# On any secure machine
openssl rand -base64 48
```

Set `SIGNOZ_JWT_SECRET` to that value in Coolify.

Do **not** leave `CHANGE_ME_*` placeholders.

### 3. Domains

| FQDN | Compose service | Container port | TLS |
|------|-----------------|----------------|-----|
| observe.polarnova.io | signoz | 8080 | Let's Encrypt |
| uptime.polarnova.io | uptime-kuma | 3001 | Let's Encrypt |
| otel.polarnova.io | otel-collector | 4318 | Let's Encrypt |

Notes:

- OTLP HTTP works well behind Coolify’s HTTPS proxy (`OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`).
- OTLP gRPC (`4317`) often needs a **TCP** proxy or direct host publish — configure if SDKs require gRPC.
- Disable Coolify “gzip” / response buffering quirks on the OTLP domain if large payloads fail.

### 4. Persistent storage

Coolify should preserve named volumes across redeploys. Confirm volumes:

- `pn-obs-clickhouse-data`
- `pn-obs-signoz-data`
- `pn-obs-uptime-kuma-data`
- `pn-obs-zookeeper-data`

Attach large disk to the Coolify server; ClickHouse is the growth driver.

### 5. Deploy

Click **Deploy**. First boot:

1. `init-clickhouse` downloads the histogram UDF (~1–2 min).
2. `clickhouse` becomes healthy.
3. `schema-migrator` runs migrations and exits `0`.
4. `signoz` + `otel-collector` + `uptime-kuma` become healthy.

### 6. First-time UI setup

1. Visit `https://observe.polarnova.io` → create admin user.
2. Visit `https://uptime.polarnova.io` → create admin user.
3. Configure retention in SigNoz (**Settings → Retention**).
4. Add monitors per `config/uptime-kuma/README.md`.

### 7. Firewall

| Port | Source |
|------|--------|
| 80/443 | Public (Coolify proxy) |
| 4317 | App servers / VPN only (if exposed) |
| Docker API / SSH | Admin only |

## Updates via Coolify

1. Bump image tags in `.env` (Coolify env) or Git.
2. Run backup scripts on the host (SSH).
3. Redeploy from Coolify (pull + recreate).
4. Run health check.

## Optional infra profile

Coolify may not expose Compose profiles cleanly. To enable node-exporter + cAdvisor:

- Add `COMPOSE_PROFILES=infra` to the environment, **or**
- Duplicate those services into the main compose without `profiles` on dedicated hosts.

## Connecting apps on the same Coolify server

If products share the Docker host, you can attach them to `polarnova-observability` and use:

```
OTEL_EXPORTER_OTLP_ENDPOINT=http://pn-obs-otel-collector:4318
```

Prefer the public HTTPS endpoint for consistency across hosts.
