# AWS Lightsail Deployment Guide (Ubuntu 24.04)

This guide prepares and deploys the existing stack on AWS Lightsail with no architecture changes.

## Architecture (Preserved)

- Runtime: Docker Compose.
- Public ingress: Caddy only on TCP `80/443`.
- LiteLLM: bound to `127.0.0.1:4000` on the VM.
- Mem0: bound to `127.0.0.1:8000` on the VM.
- Qdrant: private Docker network only.
- Postgres: Neon in production.
- Public domains:
  - `litellm.pratyushsudhakar.com`
  - `mem0.pratyushsudhakar.com`
  - `status.pratyushsudhakar.com`

## 1) Create Lightsail Instance

1. In AWS Lightsail, create an instance:
   - Platform: Linux/Unix
   - Blueprint: Ubuntu 24.04 LTS
   - Plan: at least 2 vCPU / 4 GB RAM (4 vCPU / 8 GB recommended for headroom)
2. Add an SSH key pair during creation (or attach your existing key).
3. Wait for the instance to become healthy.

## 2) Attach Static IP

1. Lightsail -> **Networking** -> **Create static IP**.
2. Attach it to your new instance.
3. Keep this IP for DNS A records.

## 3) Configure Firewall

In Lightsail Networking for the instance, allow:

- TCP `22` (SSH) from trusted IPs.
- TCP `80` from anywhere.
- TCP `443` from anywhere.

Do not expose ports `4000`, `8000`, or `6333`.

Optional host firewall (UFW on VM):

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status
```

## 4) Configure DNS

Create these A records at your DNS provider, all pointing to the Lightsail static IP:

| Name                           | Type | Value         |
| ------------------------------ | ---- | ------------- |
| `litellm.pratyushsudhakar.com` | A    | `<static-ip>` |
| `mem0.pratyushsudhakar.com`    | A    | `<static-ip>` |
| `status.pratyushsudhakar.com`  | A    | `<static-ip>` |

## 5) Install Docker and Clone Repo

### Option A (recommended): Bootstrap script

From the Ubuntu VM:

```bash
sudo apt-get update -y
sudo apt-get install -y git
git clone <your-repo-url> ~/openagent-stack
cd ~/openagent-stack
./scripts/bootstrap-lightsail.sh --repo <your-repo-url> --branch master --target-dir ~/openagent-stack
```

After bootstrap, reconnect SSH once so docker group membership is active.

### Option B: Manual install

```bash
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl git make ufw
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
newgrp docker
```

Then clone:

```bash
git clone <your-repo-url> ~/openagent-stack
cd ~/openagent-stack
```

## 6) Initialize Production Env

```bash
cd ~/openagent-stack
make install-prod
```

Edit `.env.prod` with production values (from `.env.prod.example` keys):

- Set `DATABASE_URL` to Neon production connection string.
- Keep domain/base URL values aligned to:
  - `https://litellm.pratyushsudhakar.com`
  - `https://mem0.pratyushsudhakar.com`
  - `https://status.pratyushsudhakar.com`

Never commit `.env.prod`.

## 7) First Production Deploy

```bash
cd ~/openagent-stack
make preflight-prod
make prod
make doctor-prod
```

`make prod` now force-recreates containers while preserving Docker named volumes, so service config/image updates are applied reliably without wiping state.

## 8) Verify Public Endpoints

```bash
curl -fsS https://litellm.pratyushsudhakar.com/health/liveliness
curl -fsS https://mem0.pratyushsudhakar.com/healthz
curl -fsS https://status.pratyushsudhakar.com/health
```

## 9) GitHub Actions CD (master pushes)

The workflow at `.github/workflows/deploy.yml` now:

1. Validates compose, scripts, Caddyfile, and LiteLLM config.
2. On push to `master` or `main`, SSHes into the VM.
3. Checks out the exact pushed commit SHA.
4. Runs `make preflight-prod`, config/script checks, optional `make backup-prod`.
5. Runs `make prod` (pull + recreate containers).
6. Runs `make doctor-prod`.

Required repository secrets:

- `SSH_HOST`
- `SSH_USER`
- `SSH_KEY`
- `SSH_PORT` (usually `22`)

## Data Safety Notes

- Neon remains the production database; deploys do not run destructive schema resets.
- Qdrant and Mem0 local state are on named Docker volumes (`qdrant_data`, `mem0_data`).
- CI/CD does not run `docker compose down -v` or `docker volume prune`.
- `make prod` uses `up -d --force-recreate` and keeps named volumes intact.

## Rollback

```bash
cd ~/openagent-stack
git fetch --prune origin
git checkout <previous-good-commit>
make prod
make doctor-prod
```

Use Neon restore points for database rollback when needed.

## Daily Operations

```bash
cd ~/openagent-stack
make status-prod
make logs-prod
make doctor-prod
make backup-prod
```

## Troubleshooting

```bash
cd ~/openagent-stack
make preflight-prod
make config-check-prod
make logs-prod
docker compose --env-file .env.prod -f docker-compose.yml -f docker-compose.prod.yml ps
```
