# Deployment Guide

This guide deploys the hybrid OpenAgent stack to one low-cost VPS while preserving the same service graph used locally.

## Target

- Budget: $5-15/month for infrastructure, excluding LLM API usage.
- Runtime: Docker Compose.
- Public entry point: Caddy on ports 80 and 443.
- Private services: LiteLLM, Mem0, and Qdrant behind Caddy or loopback bindings.
- Production database: Neon Postgres over TLS.
- Recovery: Neon managed restore points plus optional SQL backups stored in `backups/`.

## VPS Requirements

Recommended minimum:

- 2 vCPU, 4 GB RAM, 40 GB disk.
- 4 vCPU, 8 GB RAM if you want more room for Qdrant growth and LiteLLM/Mem0 headroom.
- Ubuntu 24.04 LTS or another Docker-supported Linux distribution.

Firewall:

- Allow SSH from your trusted IPs.
- Allow TCP 80 and 443.
- Do not expose Qdrant publicly. Production PostgreSQL lives in Neon, not on the VPS.

## DNS

Create A records pointing to the VPS:

| Record                         | Type | Value  |
| ------------------------------ | ---- | ------ |
| `litellm.pratyushsudhakar.com` | A    | VPS IP |
| `mem0.pratyushsudhakar.com`    | A    | VPS IP |
| `status.pratyushsudhakar.com`  | A    | VPS IP |

## First-Time Server Setup

Install Docker:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
newgrp docker
```

Clone the repository:

```bash
git clone <your-repo-url> ~/openagent-stack
cd ~/openagent-stack
make install-prod
```

Fill in `.env.prod` on the server with the runtime values required by `.env.prod.example`.

For production database settings, set:

- `DATABASE_URL` to your Neon connection string.

Mem0 does not require separate Neon or PostgreSQL settings. It uses Qdrant for vector storage and keeps lightweight API history in the `mem0_data` Docker volume.

## Manual Production Deploy

```bash
cd ~/openagent-stack
make prod
```

This performs:

1. Production compose config validation.
2. Image pulls.
3. Container start/update.
4. Production health checks.

Check status:

```bash
make status-prod
make doctor-prod
```

## CI/CD Deploy

GitHub Actions validates every pull request and deploys pushes to `main` or `master`.

Required repository secrets:

| Secret     | Description                   |
| ---------- | ----------------------------- |
| `SSH_HOST` | VPS hostname or IP            |
| `SSH_USER` | SSH user                      |
| `SSH_KEY`  | Private key for deploy access |
| `SSH_PORT` | SSH port, usually `22`        |

The deploy job:

1. Pulls the branch with `git pull --ff-only`.
2. Runs production config checks.
3. Attempts an optional Neon logical backup.
4. Pulls images.
5. Starts the production compose overlay.
6. Runs `STACK_PROFILE=prod ./scripts/health-check.sh`.
7. Prunes old Docker images.

## Local Development

Run the same backend stack locally:

```bash
make install-local
make dev
make doctor
make agent-config-local
```

`make install-local` creates `.env.local` from `.env.local.example`.

Default local endpoints:

| Service    | URL                        |
| ---------- | -------------------------- |
| LiteLLM    | `http://localhost:4000`    |
| LiteLLM UI | `http://localhost:4000/ui` |
| Mem0       | `http://localhost:8000`    |
| Qdrant     | `http://localhost:6333`    |
| PostgreSQL | `127.0.0.1:55432`          |

## Remote Agent Config

Generate a remote OpenAgent config:

```bash
make agent-config-remote DOMAIN=pratyushsudhakar.com
```

By default, generated configs keep the placeholder key `sk-litellm-master`. If you choose to embed a real key, pass it directly to `scripts/render-openagent-config.sh` and keep the generated output under `.generated/`, which is ignored.

## URL Rules

- Local templates use `localhost` because they are for your Mac.
- Production templates use public HTTPS domains for client-facing values.
- Production compose still binds LiteLLM and Mem0 to `127.0.0.1` on the VPS. That is intentional: Caddy is the only public ingress.
- Docker health checks use `localhost` inside the container namespace. Those are not public URLs.

## Backups

Create a production Neon logical backup:

```bash
make backup-prod
```

Create a local backup:

```bash
make backup
```

Backups are written as:

```text
backups/backup-YYYYMMDD-HHMMSS.sql
```

Neon already provides managed restore points. If you also want a daily logical SQL dump, add this VPS cron:

```bash
0 3 * * * cd ~/openagent-stack && make backup-prod >> /var/log/openagent-backup.log 2>&1
```

## Restore Drill

Run this after major stack changes so logical backups are known to be usable:

```bash
make backup-prod
make restore-prod
make doctor-prod
```

For a destructive recovery from a fresh VPS:

1. Install Docker.
2. Clone the repo.
3. Restore `.env.prod` from your password manager.
4. Copy the SQL backup into `backups/`.
5. Run `make prod`.
6. Restore from Neon if needed, or run `make restore-prod` for a logical SQL backup.
7. Run `make doctor-prod`.

## Rollback

If a deploy fails before services are replaced, fix the validation error and rerun the workflow.

If a deploy fails after containers are updated:

```bash
cd ~/openagent-stack
git log --oneline -5
git checkout <previous-good-commit>
make prod
make restore-prod
make doctor-prod
```

Use Neon restore points for most production database rollbacks. Use `make restore-prod` only when intentionally restoring a logical SQL dump.

## Troubleshooting

Check logs:

```bash
make logs-prod
```

Check individual services:

```bash
docker compose --env-file .env.prod -f docker-compose.yml -f docker-compose.prod.yml logs litellm --tail=100
docker compose --env-file .env.prod -f docker-compose.yml -f docker-compose.prod.yml logs mem0 --tail=100
docker compose --env-file .env.prod -f docker-compose.yml -f docker-compose.prod.yml logs caddy --tail=100
```

Validate configs:

```bash
make config-check
```

Check public endpoints:

```bash
curl -fsS https://litellm.pratyushsudhakar.com/health/liveliness
curl -fsS https://mem0.pratyushsudhakar.com/healthz
curl -fsS https://status.pratyushsudhakar.com/health
```

## Future Upgrades

Consider these only when the need is clear:

- Redis for persistent LiteLLM budget state across restarts.
- Neon branching for safer production restore drills and staging databases.
- Prometheus/Grafana if health checks are not enough.
- Kubernetes/GitOps if there are multiple operators, multiple nodes, or a real HA requirement.
