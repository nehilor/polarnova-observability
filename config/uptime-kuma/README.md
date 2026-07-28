# Uptime Kuma configuration

Uptime Kuma stores monitor definitions in its persistent volume (`pn-obs-uptime-kuma-data`).
There is no declarative YAML for monitors in the OSS image — configure via the UI after first boot.

## First login

1. Open `https://uptime.polarnova.io`
2. Create the admin account (store credentials in your password manager)
3. Optionally enable 2FA

## Recommended monitor set (PolarNova)

| Name | Type | Target | Interval | Notes |
|------|------|--------|----------|-------|
| SigNoz UI | HTTP(s) | `https://observe.polarnova.io/api/v1/health` | 60s | Expect 200 |
| OTLP HTTP | HTTP(s) | `https://otel.polarnova.io/v1/traces` | 120s | POST may 400 — use keyword/status accept list |
| Vital AI | HTTP(s) | production health URL | 60s | App-specific |
| VoxPilot | HTTP(s) | production health URL | 60s | App-specific |
| Foodiiz | HTTP(s) | production health URL | 60s | App-specific |
| AI Drop Cloud | HTTP(s) | production health URL | 60s | App-specific |
| Operator | HTTP(s) | production health URL | 60s | Internal |
| Coolify | HTTP(s) | Coolify dashboard URL | 60s | Infra |
| Mail SMTP | TCP | `mail:587` or public MX:587 | 120s | Port check |
| Mail IMAP | TCP | `mail:993` | 120s | Port check |
| PostgreSQL | TCP | DB host:5432 | 120s | From network that can reach DB |
| Redis | TCP | Redis host:6379 | 120s | |
| SSL — observe | SSL Cert | `observe.polarnova.io` | 1d | Alert < 14 days |
| SSL — uptime | SSL Cert | `uptime.polarnova.io` | 1d | |
| SSL — otel | SSL Cert | `otel.polarnova.io` | 1d | |
| SSL — product domains | SSL Cert | each public domain | 1d | |

## Notifications

Configure at least one channel:

- Slack / Discord webhook
- Email (SMTP)
- Telegram

Route critical monitors (SigNoz, Coolify, production apps) to on-call.

## Status page (optional)

Uptime Kuma can publish a public status page — keep internal products private.
