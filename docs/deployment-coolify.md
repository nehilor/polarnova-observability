# Coolify notes (English pointer)

The authoritative Coolify runbook is in Spanish:

→ **[COOLIFY_DEPLOYMENT_GUIDE.md](../COOLIFY_DEPLOYMENT_GUIDE.md)**

Critical rules from Coolify docs:

- Prefer `expose` over host `ports` for proxied UI services.
- Domain format for non-80 ports: `https://observe.polarnova.io:8080` on service `signoz`.
- Avoid custom Docker networks that dual-home containers away from Traefik.
