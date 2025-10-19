#!/usr/bin/env bash
set -euo pipefail

CURRENT_USER="$(id -un 2>/dev/null || true)"
[[ -z "$CURRENT_USER" && -f /etc/actual-user ]] && CURRENT_USER="$(cat /etc/actual-user 2>/dev/null || true)"
[[ -z "$CURRENT_USER" ]] && CURRENT_USER="dev"

SOCK=/var/run/docker.sock
if [[ -S "$SOCK" ]]; then
  SOCK_GID=$(stat -c %g "$SOCK" 2>/dev/null || echo "")
  if [[ -n "$SOCK_GID" ]]; then
    if getent group "$SOCK_GID" >/dev/null 2>&1; then
      DOCKER_GRP_NAME="$(getent group "$SOCK_GID" | cut -d: -f1)"
    else
      DOCKER_GRP_NAME=docker
      sudo groupadd -g "$SOCK_GID" "$DOCKER_GRP_NAME" 2>/dev/null || true
    fi
    sudo usermod -aG "$DOCKER_GRP_NAME" "$CURRENT_USER" 2>/dev/null || true
  fi
fi

# Auto-bootstrap GitHub known_hosts if agent is forwarded
if [[ -n "${SSH_AUTH_SOCK:-}" && -S "${SSH_AUTH_SOCK}" ]]; then
  HOME_DIR="$(getent passwd "$CURRENT_USER" | cut -d: -f6)"
  mkdir -p "$HOME_DIR/.ssh"
  chmod 700 "$HOME_DIR/.ssh" || true
  KN="$HOME_DIR/.ssh/known_hosts"
  touch "$KN" && chmod 644 "$KN"
  grep -q "github.com" "$KN" 2>/dev/null || ssh-keyscan -H github.com >> "$KN" 2>/dev/null || true
fi

exec "$@"