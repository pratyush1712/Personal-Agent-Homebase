#!/usr/bin/env bash
# Preflight checks for Lightsail production deployments.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.prod}"

log() {
  printf "[preflight] %s\n" "$1"
}

fail() {
  printf "[preflight][error] %s\n" "$1" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required command: ${cmd}"
  fi
}

main() {
  cd "$REPO_ROOT"

  require_cmd "docker"
  require_cmd "git"
  require_cmd "curl"

  if [ ! -f "$ENV_FILE" ]; then
    fail "Missing environment file: ${ENV_FILE}"
  fi

  if ! docker info >/dev/null 2>&1; then
    fail "Docker daemon is not reachable. Start Docker and retry."
  fi

  if ! docker compose version >/dev/null 2>&1; then
    fail "Docker Compose plugin is not available."
  fi

  log "Validating production compose syntax"
  docker compose --env-file "$ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml config --no-interpolate >/dev/null

  log "Validating Caddyfile syntax"
  docker run --rm -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile >/dev/null

  mkdir -p backups .generated
  log "Preflight checks passed"
}

main "$@"
