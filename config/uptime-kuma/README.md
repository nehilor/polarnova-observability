# Uptime Kuma — synthetic monitoring (separate from SigNoz APM)

Data lives in volume `pn-obs-uptime-kuma-data`.

## First deploy

1. Keep **without** a public Coolify domain until admin exists.
2. Reach UI via private path (Coolify terminal tunnel / Tailscale / temporary local forward).
3. Create admin + enable 2FA if available.
4. Then optionally assign `https://uptime.polarnova.io:3001` on service `uptime-kuma`.

## Suggested monitors

| Name | Type | Target |
|------|------|--------|
| SigNoz UI | HTTP(s) | `https://observe.polarnova.io/api/v1/health` |
| Product sites / APIs | HTTP(s) | public health URLs |
| SSL certificates | SSL | public hostnames |
| DNS | DNS | critical records |
| SMTP | TCP | mail:587 / :465 |
| IMAP | TCP | mail:993 |
| PostgreSQL | TCP | via Tailscale/private net |
| Redis | TCP | via Tailscale/private net |

Do not monitor public OTLP (there is none).
