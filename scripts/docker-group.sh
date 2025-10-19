#!/usr/bin/env bash
set -euo pipefail

# Resolve the current login name robustly even if $USER is unset
CURRENT_USER="$(id -un 2>/dev/null || true)"
if [[ -z "$CURRENT_USER" && -f /etc/actual-user ]]; then
  CURRENT_USER="$(cat /etc/actual-user 2>/dev/null || true)"
fi
if [[ -z "$CURRENT_USER" ]]; then
  CURRENT_USER="dev"
fi

# If the host Docker socket is mounted, align group so the non-root user can talk to it
SOCK=/var/run/docker.sock
if [[ -S "$SOCK" ]]; then
  SOCK_GID=$(stat -c %g "$SOCK" 2>/dev/null || echo "")
  if [[ -n "$SOCK_GID" ]]; then
    # Find or create a group name for this GID
    if getent group "$SOCK_GID" >/dev/null 2>&1; then
      DOCKER_GRP_NAME="$(getent group "$SOCK_GID" | cut -d: -f1)"
    else
      DOCKER_GRP_NAME=docker
      # Create 'docker' group with the socket's gid; ignore if race/exists
      sudo groupadd -g "$SOCK_GID" "$DOCKER_GRP_NAME" 2>/dev/null || true
    fi
    # Add the current user to that group name
    sudo usermod -aG "$DOCKER_GRP_NAME" "$CURRENT_USER" 2>/dev/null || true
  fi
fi

# If an SSH agent was forwarded, nothing to change; it's mounted read-only and used as-is
exec "$@"