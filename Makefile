# Oh-My-OpenAgent + LiteLLM + Mem0 — Hybrid Workflow
# Usage: make <target>

SHELL := /bin/bash

DOMAIN ?= pratyushsudhakar.com
LOCAL_ENV_FILE ?= .env.local
PROD_ENV_FILE ?= .env.prod
POSTGRES_DB ?= openagent
POSTGRES_USER ?= openagent

COMPOSE_BASE := docker compose
COMPOSE_LOCAL := $(COMPOSE_BASE) --env-file "$(LOCAL_ENV_FILE)" -f docker-compose.yml -f docker-compose.local.yml -p openagent-local
COMPOSE_PROD := $(COMPOSE_BASE) --env-file "$(PROD_ENV_FILE)" -f docker-compose.yml -f docker-compose.prod.yml -p openagent-prod
WITH_LOCAL_ENV := ./scripts/with-env.sh "$(LOCAL_ENV_FILE)"
WITH_PROD_ENV := ./scripts/with-env.sh "$(PROD_ENV_FILE)"

.PHONY: help install install-local install-prod require-local-env require-prod-env preflight-prod bootstrap-lightsail dev prod deploy status status-prod logs logs-prod logs-litellm-prod logs-mem0-prod logs-qdrant-prod logs-caddy-prod logs-grafana-prod logs-uptime-prod stop stop-prod restart restart-prod backup backup-prod restore restore-prod clean clean-prod doctor doctor-prod test config-check config-check-local config-check-prod scripts-check agent-config-local agent-config-remote update update-prod rollback-prod qdrant-health-prod qdrant-collections-prod qdrant-info-prod qdrant-tunnel-prod

help:
	@echo "OpenAgent Stack — Hybrid Commands"
	@echo ""
	@echo "  --- Setup ---"
	@echo "  make install-local        Create .env.local from .env.local.example"
	@echo "  make install-prod         Create .env.prod from .env.prod.example"
	@echo "  make bootstrap-lightsail  Install Docker + firewall on Lightsail"
	@echo ""
	@echo "  --- Deploy ---"
	@echo "  make preflight-prod       Validate host before production deploy"
	@echo "  make dev                  Start the local development stack"
	@echo "  make prod                 Start/update the production VPS stack"
	@echo "  make rollback-prod COMMIT=<sha>  Roll back production to a specific git commit"
	@echo ""
	@echo "  --- Health / Monitoring ---"
	@echo "  make doctor               Check local containers and endpoints"
	@echo "  make doctor-prod          Check production containers and endpoints"
	@echo ""
	@echo "  --- Logs ---"
	@echo "  make logs-prod            Tail all production containers"
	@echo "  make logs-litellm-prod    Tail LiteLLM only"
	@echo "  make logs-mem0-prod       Tail Mem0 only"
	@echo "  make logs-qdrant-prod     Tail Qdrant only"
	@echo "  make logs-caddy-prod      Tail Caddy only"
	@echo "  make logs-grafana-prod    Tail Grafana only"
	@echo "  make logs-uptime-prod     Tail Uptime Kuma only"
	@echo ""
	@echo "  --- Qdrant ---"
	@echo "  make qdrant-health-prod       Quick healthz check (run from server or Mac)"
	@echo "  make qdrant-collections-prod  List collections + vector counts"
	@echo "  make qdrant-info-prod         Full cluster info JSON"
	@echo "  make qdrant-tunnel-prod SSH_HOST=<ip>  SSH tunnel → http://localhost:6333/dashboard"
	@echo ""
	@echo "  --- Operations ---"
	@echo "  make status|logs|stop     Operate on the local stack"
	@echo "  make status-prod|stop-prod"
	@echo "  make backup|restore       Backup or restore the local PostgreSQL data"
	@echo "  make backup-prod|restore-prod"
	@echo "  make config-check         Validate compose files and shell scripts"
	@echo "  make agent-config-local   Render .generated/oh-my-openagent.local.jsonc"
	@echo "  make agent-config-remote  Render .generated/oh-my-openagent.remote.jsonc"

install: install-local

install-local:
	@if [ ! -f "$(LOCAL_ENV_FILE)" ]; then \
		cp .env.local.example "$(LOCAL_ENV_FILE)"; \
		echo "Created $(LOCAL_ENV_FILE) from .env.local.example."; \
	else \
		echo "$(LOCAL_ENV_FILE) exists, continuing..."; \
	fi
	@mkdir -p backups .generated
	@echo "Setup complete. Fill in $(LOCAL_ENV_FILE), then run make dev."

install-prod:
	@if [ ! -f "$(PROD_ENV_FILE)" ]; then \
		cp .env.prod.example "$(PROD_ENV_FILE)"; \
		echo "Created $(PROD_ENV_FILE) from .env.prod.example."; \
	else \
		echo "$(PROD_ENV_FILE) exists, continuing..."; \
	fi
	@mkdir -p backups .generated
	@echo "Setup complete. Fill in $(PROD_ENV_FILE), then run make prod on the VPS."

require-local-env:
	@if [ ! -f "$(LOCAL_ENV_FILE)" ]; then \
		echo "$(LOCAL_ENV_FILE) not found. Run make install-local first."; \
		exit 1; \
	fi

require-prod-env:
	@if [ ! -f "$(PROD_ENV_FILE)" ]; then \
		echo "$(PROD_ENV_FILE) not found. Run make install-prod first."; \
		exit 1; \
	fi

preflight-prod: require-prod-env
	@ENV_FILE="$(PROD_ENV_FILE)" ./scripts/preflight-prod.sh

bootstrap-lightsail:
	@./scripts/bootstrap-lightsail.sh --help

dev: require-local-env config-check-local
	@echo "Starting local OpenAgent stack..."
	@$(COMPOSE_LOCAL) up -d --remove-orphans
	@$(MAKE) doctor

prod: require-prod-env preflight-prod config-check-prod
	@echo "Starting production OpenAgent stack..."
	@$(COMPOSE_PROD) pull
	@$(COMPOSE_PROD) up -d --build --remove-orphans --force-recreate
	@$(MAKE) doctor-prod
	@$(WITH_PROD_ENV) bash -lc 'echo "LiteLLM UI:  $${PROXY_LOGOUT_URL:-$${LITELLM_BASE_URL%/}/ui}"; echo "Mem0 API:    $${MEM0_BASE_URL:-https://mem0.$${DOMAIN:-$(DOMAIN)}}"; echo "Status:      https://status.$${DOMAIN:-$(DOMAIN)}/health"'

deploy: prod

status: require-local-env
	@$(COMPOSE_LOCAL) ps

status-prod: require-prod-env
	@$(COMPOSE_PROD) ps

logs: require-local-env
	@$(COMPOSE_LOCAL) logs -f --tail=100

logs-prod: require-prod-env
	@$(COMPOSE_PROD) logs -f --tail=100

logs-litellm-prod: require-prod-env
	@$(COMPOSE_PROD) logs -f --tail=200 litellm

logs-mem0-prod: require-prod-env
	@$(COMPOSE_PROD) logs -f --tail=200 mem0

logs-qdrant-prod: require-prod-env
	@$(COMPOSE_PROD) logs -f --tail=200 qdrant

logs-caddy-prod: require-prod-env
	@$(COMPOSE_PROD) logs -f --tail=200 caddy

logs-grafana-prod: require-prod-env
	@$(COMPOSE_PROD) logs -f --tail=200 grafana

logs-uptime-prod: require-prod-env
	@$(COMPOSE_PROD) logs -f --tail=200 uptime-kuma

stop: require-local-env
	@$(COMPOSE_LOCAL) down

stop-prod: require-prod-env
	@$(COMPOSE_PROD) down

restart: require-local-env
	@$(COMPOSE_LOCAL) restart

restart-prod: require-prod-env
	@$(COMPOSE_PROD) restart

backup: require-local-env
	@mkdir -p backups
	@$(COMPOSE_LOCAL) exec -T postgres pg_dump -U "$(POSTGRES_USER)" "$(POSTGRES_DB)" > backups/backup-$$(date +%Y%m%d-%H%M%S).sql
	@echo "Backup saved to backups/"

backup-prod: require-prod-env
	@mkdir -p backups
	@$(WITH_PROD_ENV) bash -lc 'if [ -z "$${DATABASE_URL:-}" ]; then echo "DATABASE_URL is missing in $(PROD_ENV_FILE)."; exit 1; fi; docker run --rm postgres:16-alpine pg_dump "$$DATABASE_URL" > backups/neon-backup-$$(date +%Y%m%d-%H%M%S).sql'
	@echo "Neon backup saved to backups/"

restore: require-local-env
	@latest_backup=$$(python3 -c 'from pathlib import Path; backups = sorted(Path("backups").glob("*.sql"), reverse=True); print(backups[0] if backups else "")'); \
	if [ -z "$$latest_backup" ]; then \
		echo "No backup files found in backups/"; \
		exit 1; \
	fi; \
	echo "Restoring from $$latest_backup..."; \
	$(COMPOSE_LOCAL) exec -T postgres psql -U "$(POSTGRES_USER)" "$(POSTGRES_DB)" < "$$latest_backup"
	@echo "Restore complete."

restore-prod: require-prod-env
	@latest_backup=$$(python3 -c 'from pathlib import Path; backups = sorted(Path("backups").glob("*.sql"), reverse=True); print(backups[0] if backups else "")'); \
	if [ -z "$$latest_backup" ]; then \
		echo "No backup files found in backups/"; \
		exit 1; \
	fi; \
	echo "Restoring Neon from $$latest_backup..."; \
	$(WITH_PROD_ENV) bash -lc 'if [ -z "$${DATABASE_URL:-}" ]; then echo "DATABASE_URL is missing in $(PROD_ENV_FILE)."; exit 1; fi; docker run --rm -i postgres:16-alpine psql "$$DATABASE_URL" < "$$0"' "$$latest_backup"
	@echo "Neon restore complete."

clean: require-local-env
	@echo "WARNING: This removes local stack containers and volumes."
	@read -r -p "Are you sure? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		$(COMPOSE_LOCAL) down -v --rmi local; \
		echo "Local stack cleaned."; \
	else \
		echo "Aborted."; \
	fi

clean-prod: require-prod-env
	@echo "WARNING: This removes production stack containers and volumes."
	@read -r -p "Are you sure? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		$(COMPOSE_PROD) down -v --rmi local; \
		echo "Production stack cleaned."; \
	else \
		echo "Aborted."; \
	fi

doctor: require-local-env
	@ENV_FILE="$(LOCAL_ENV_FILE)" STACK_PROFILE=local ./scripts/health-check.sh

doctor-prod: require-prod-env
	@ENV_FILE="$(PROD_ENV_FILE)" STACK_PROFILE=prod ./scripts/health-check.sh

test: doctor

config-check: config-check-local config-check-prod

config-check-local: require-local-env scripts-check
	@$(COMPOSE_LOCAL) config --no-interpolate > /dev/null
	@echo "Local compose config: OK"

config-check-prod: require-prod-env scripts-check
	@$(COMPOSE_PROD) config --no-interpolate > /dev/null
	@echo "Production compose config: OK"
	

scripts-check:
	@bash -n scripts/health-check.sh
	@bash -n scripts/preflight-prod.sh
	@bash -n scripts/bootstrap-lightsail.sh
	@bash -n scripts/render-openagent-config.sh
	@bash -n scripts/with-env.sh
	@echo "Shell scripts: OK"

agent-config-local: require-local-env
	@mkdir -p .generated
	@$(WITH_LOCAL_ENV) bash -lc './scripts/render-openagent-config.sh --mode local --base-url "$${LITELLM_BASE_URL%/}/v1" --key "$${LITELLM_MASTER_KEY:-sk-litellm-master}" --output .generated/oh-my-openagent.local.jsonc'

agent-config-remote: require-prod-env
	@mkdir -p .generated
	@$(WITH_PROD_ENV) bash -lc './scripts/render-openagent-config.sh --mode remote --base-url "$${LITELLM_BASE_URL%/}/v1" --domain "$${DOMAIN:-$(DOMAIN)}" --key "$${LITELLM_MASTER_KEY:-sk-litellm-master}" --output .generated/oh-my-openagent.remote.jsonc'

# ── Rollback ────────────────────────────────────────────────────────────────
# Usage: make rollback-prod COMMIT=<git-sha>
# Checks out the specified commit and re-deploys the production stack.
rollback-prod: require-prod-env
	@if [ -z "$(COMMIT)" ]; then \
		echo "Usage: make rollback-prod COMMIT=<git-sha>"; \
		exit 1; \
	fi
	@echo "Rolling back production to $(COMMIT)..."
	git fetch origin
	git checkout "$(COMMIT)"
	$(MAKE) prod
	$(MAKE) doctor-prod
	@echo "Rollback to $(COMMIT) complete."

# ── Qdrant Developer Access ─────────────────────────────────────────────────
# These targets work both from the Lightsail server terminal and from your Mac
# (except qdrant-tunnel-prod which requires network access to the server).

SSH_HOST ?=
SSH_USER ?= ubuntu

qdrant-health-prod: require-prod-env
	@$(COMPOSE_PROD) exec qdrant wget -qO- http://localhost:6333/healthz

qdrant-collections-prod: require-prod-env
	@$(COMPOSE_PROD) exec qdrant wget -qO- http://localhost:6333/collections

qdrant-info-prod: require-prod-env
	@$(COMPOSE_PROD) exec qdrant wget -qO- http://localhost:6333/cluster

# Opens an SSH tunnel from your Mac to the Qdrant container.
# Then visit http://localhost:6333/dashboard in Chrome.
# Press Ctrl-C to close the tunnel.
# Usage: make qdrant-tunnel-prod SSH_HOST=<lightsail-static-ip>
qdrant-tunnel-prod:
	@if [ -z "$(SSH_HOST)" ]; then \
		echo "Usage: make qdrant-tunnel-prod SSH_HOST=<lightsail-static-ip> [SSH_USER=ubuntu]"; \
		exit 1; \
	fi
	@echo "Finding Qdrant container IP on $(SSH_HOST)..."
	$(eval QDRANT_IP := $(shell ssh "$(SSH_USER)@$(SSH_HOST)" \
		"docker inspect \$$(docker compose -p openagent-prod ps -q qdrant 2>/dev/null | head -1) \
		--format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null"))
	@if [ -z "$(QDRANT_IP)" ]; then \
		echo "Could not find Qdrant container IP. Is the production stack running?"; \
		exit 1; \
	fi
	@echo "Tunnel open: http://localhost:6333/dashboard"
	@echo "Press Ctrl-C to close."
	@ssh -N -L "6333:$(QDRANT_IP):6333" "$(SSH_USER)@$(SSH_HOST)"

update: dev

update-prod: prod
