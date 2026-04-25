#!/usr/bin/env bash
# Bootstrap an Ubuntu 24.04 Lightsail VM for this repository.

set -euo pipefail

REPO_URL=""
TARGET_BRANCH="master"
TARGET_DIR="${HOME}/openagent-stack"

usage() {
  cat <<EOF
Usage: $0 --repo <git-url> [--branch <branch>] [--target-dir <dir>]

Examples:
  $0 --repo git@github.com:your-org/Personal-Agent-Homebase.git
  $0 --repo https://github.com/your-org/Personal-Agent-Homebase.git --branch master
EOF
}

log() {
  printf "[bootstrap] %s\n" "$1"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --repo)
        REPO_URL="${2:-}"
        shift 2
        ;;
      --branch)
        TARGET_BRANCH="${2:-}"
        shift 2
        ;;
      --target-dir)
        TARGET_DIR="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 2
        ;;
    esac
  done
}

install_packages() {
  log "Installing system packages"
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl git make ufw
}

install_docker_if_needed() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed"
    return
  fi

  log "Installing Docker Engine and Compose plugin"
  curl -fsSL https://get.docker.com | sh
}

configure_user_access() {
  if id -nG "$USER" | grep -qw docker; then
    log "User already in docker group"
  else
    log "Adding user to docker group"
    sudo usermod -aG docker "$USER"
  fi
}

configure_firewall() {
  log "Configuring UFW firewall (SSH, 80, 443)"
  sudo ufw allow OpenSSH
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw --force enable
}

prepare_repo() {
  if [ -d "${TARGET_DIR}/.git" ]; then
    log "Repository exists, updating ${TARGET_DIR}"
    git -C "$TARGET_DIR" fetch --prune origin
    git -C "$TARGET_DIR" checkout "$TARGET_BRANCH"
    git -C "$TARGET_DIR" pull --ff-only origin "$TARGET_BRANCH"
    return
  fi

  log "Cloning repository into ${TARGET_DIR}"
  git clone --branch "$TARGET_BRANCH" "$REPO_URL" "$TARGET_DIR"
}

main() {
  parse_args "$@"

  if [ -z "$REPO_URL" ]; then
    echo "Missing required --repo argument" >&2
    usage
    exit 2
  fi

  install_packages
  install_docker_if_needed
  configure_user_access
  configure_firewall
  prepare_repo

  log "Bootstrap complete"
  log "Open a new SSH session, then run:"
  log "  cd ${TARGET_DIR}"
  log "  make install-prod"
  log "  make prod"
}

main "$@"
