#!/usr/bin/env bash
# =============================================================================
# Health Check Script for the hybrid OpenAgent stack.
# Usage:
#   STACK_PROFILE=local ./scripts/health-check.sh
#   STACK_PROFILE=prod  ./scripts/health-check.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_PROFILE="${STACK_PROFILE:-local}"
ENV_FILE="${ENV_FILE:-}"
TIMEOUT="${TIMEOUT:-10}"
VERBOSE="${VERBOSE:-false}"
HEALTH_ATTEMPTS="${HEALTH_ATTEMPTS:-30}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-5}"
LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
MEM0_URL="${MEM0_URL:-http://localhost:8000}"
CADDY_URL="${CADDY_URL:-http://localhost:80}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

case "$STACK_PROFILE" in
    local)
        if [ -z "$ENV_FILE" ]; then
            ENV_FILE=".env.local"
        fi
        compose_args=(-f docker-compose.yml -f docker-compose.local.yml)
        compose_project="openagent-local"
        check_caddy=false
        database_mode="local"
        services=(litellm mem0 postgres qdrant)
        ;;
    prod)
        if [ -z "$ENV_FILE" ]; then
            ENV_FILE=".env.prod"
        fi
        compose_args=(-f docker-compose.yml -f docker-compose.prod.yml)
        compose_project="openagent-prod"
        check_caddy=true
        database_mode="neon"
        services=(caddy litellm mem0 qdrant uptime-kuma loki promtail grafana)
        ;;
    *)
        echo "STACK_PROFILE must be local or prod" >&2
        exit 2
        ;;
esac

if [ "${OPENAGENT_ENV_LOADED:-false}" != "true" ]; then
    if [ ! -f "$ENV_FILE" ]; then
        echo "Environment file not found: $ENV_FILE" >&2
        exit 1
    fi

    export STACK_PROFILE ENV_FILE TIMEOUT VERBOSE HEALTH_ATTEMPTS HEALTH_INTERVAL
    export LITELLM_URL MEM0_URL CADDY_URL OPENAGENT_ENV_LOADED=true
    exec "$SCRIPT_DIR/with-env.sh" "$ENV_FILE" "$0" "$@"
fi

POSTGRES_DB="${POSTGRES_DB:-openagent}"
POSTGRES_USER="${POSTGRES_USER:-openagent}"

compose() {
    docker compose "${compose_args[@]}" -p "$compose_project" "$@"
}

log_info() { printf "%b[INFO]%b %s\n" "$GREEN" "$NC" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"; }
log_error() { printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1"; }

health_check() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    local attempt
    local http_code

    for ((attempt = 1; attempt <= HEALTH_ATTEMPTS; attempt++)); do
        if [ "$VERBOSE" = "true" ]; then
            log_info "Checking $name at $url (attempt $attempt/$HEALTH_ATTEMPTS)"
        fi

        http_code=$(curl -fsS -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null) || {
            if [ "$attempt" -lt "$HEALTH_ATTEMPTS" ]; then
                sleep "$HEALTH_INTERVAL"
                continue
            fi

            log_error "$name is UNHEALTHY (request failed)"
            return 1
        }

        if [ "$http_code" = "$expected_code" ]; then
            log_info "$name is HEALTHY (HTTP $http_code)"
            return 0
        fi

        if [ "$attempt" -lt "$HEALTH_ATTEMPTS" ]; then
            sleep "$HEALTH_INTERVAL"
        fi
    done

    log_error "$name is UNHEALTHY (HTTP $http_code, expected $expected_code)"
    return 1
}

check_service() {
    local service="$1"
    local name
    local status
    local health
    local attempt

    name=$(compose ps -q "$service") || {
        log_error "$service service not found"
        return 1
    }

    if [ -z "$name" ]; then
        log_error "$service service is not created"
        return 1
    fi

    for ((attempt = 1; attempt <= HEALTH_ATTEMPTS; attempt++)); do
        status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null) || {
            log_error "$service container not found"
            return 1
        }

        if [ "$status" != "running" ]; then
            if [ "$attempt" -lt "$HEALTH_ATTEMPTS" ]; then
                sleep "$HEALTH_INTERVAL"
                continue
            fi

            log_error "$service container is $status"
            return 1
        fi

        health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || echo "unknown")
        case "$health" in
            healthy|none)
                log_info "$service container is RUNNING (health: $health)"
                return 0
                ;;
            starting)
                if [ "$attempt" -lt "$HEALTH_ATTEMPTS" ]; then
                    sleep "$HEALTH_INTERVAL"
                    continue
                fi
                ;;
            *)
                log_warn "$service container is RUNNING but health is: $health"
                return 1
                ;;
        esac
    done

    log_warn "$service container is RUNNING but health is: $health"
    return 1
}

service_container_ids() {
    local service

    for service in "${services[@]}"; do
        compose ps -q "$service"
    done
}

check_local_database() {
    if compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" > /dev/null 2>&1; then
        log_info "Local PostgreSQL is accepting connections"
        return 0
    fi

    log_error "Local PostgreSQL is NOT accepting connections"
    return 1
}

check_neon_database() {
    if [ -z "${DATABASE_URL:-}" ]; then
        log_warn "DATABASE_URL is not exported; skipping direct Neon connectivity check"
        return 0
    fi

    if command -v pg_isready > /dev/null 2>&1; then
        if pg_isready -d "$DATABASE_URL" > /dev/null 2>&1; then
            log_info "Neon PostgreSQL is accepting connections"
            return 0
        fi
    elif docker run --rm postgres:16-alpine pg_isready -d "$DATABASE_URL" > /dev/null 2>&1; then
        log_info "Neon PostgreSQL is accepting connections"
        return 0
    fi

    log_error "Neon PostgreSQL is NOT accepting connections"
    return 1
}

main() {
    local exit_code=0

    echo "=========================================="
    echo "OpenAgent Stack Health Check ($STACK_PROFILE)"
    echo "=========================================="
    echo ""

    echo "--- Container Status ---"
    for service in "${services[@]}"; do
        check_service "$service" || exit_code=1
    done
    echo ""

    echo "--- HTTP Endpoints ---"
    if [ "$check_caddy" = "true" ]; then
        health_check "Caddy" "$CADDY_URL/health" || exit_code=1
        health_check "Uptime Kuma" "http://localhost:3001" || exit_code=1
        health_check "Grafana" "http://localhost:3000/api/health" || exit_code=1
    fi
    health_check "LiteLLM Liveliness" "$LITELLM_URL/health/liveliness" || exit_code=1
    health_check "LiteLLM Readiness" "$LITELLM_URL/health/readiness" || exit_code=1
    health_check "Mem0" "$MEM0_URL/healthz" || exit_code=1
    echo ""

    echo "--- Database ---"
    case "$database_mode" in
        local)
            check_local_database || exit_code=1
            ;;
        neon)
            check_neon_database || exit_code=1
            ;;
    esac
    echo ""

    echo "--- Resource Usage ---"
    container_ids=$(service_container_ids | tr "\n" " ")
    if [ -n "$container_ids" ]; then
        # shellcheck disable=SC2086
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" $container_ids 2>/dev/null || true
    fi
    echo ""

    echo "=========================================="
    if [ "$exit_code" -eq 0 ]; then
        log_info "ALL CHECKS PASSED"
    else
        log_error "SOME CHECKS FAILED"
    fi
    echo "=========================================="

    exit "$exit_code"
}

main "$@"
