# Base: minimal, fast; works on Apple Silicon and Intel
FROM ubuntu:24.04

ARG USERNAME=dev
ARG HOST_UID=1000
ARG HOST_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    # Enable BuildKit by default inside the dev box
    DOCKER_BUILDKIT=1

# Core dev tools; keep lean and add as needed
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git bash zsh sudo build-essential pkg-config \
    openssh-client jq unzip less vim \
  && rm -rf /var/lib/apt/lists/*

# Docker CLI + Compose plugin (talks to host dockerd via socket)
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && . /etc/os-release \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list \
 && apt-get update && apt-get install -y --no-install-recommends \
    docker-ce-cli docker-compose-plugin \
 && rm -rf /var/lib/apt/lists/*

# Create or reuse a non-root user matching HOST_UID/HOST_GID (handles colliding IDs)
RUN set -eux; \
    # Ensure a group with HOST_GID exists (reuse if present)
    if getent group "${HOST_GID}" >/dev/null 2>&1; then \
      TARGET_GRP_NAME="$(getent group "${HOST_GID}" | cut -d: -f1)"; \
    else \
      TARGET_GRP_NAME="${USERNAME}"; \
      groupadd -g "${HOST_GID}" "$TARGET_GRP_NAME"; \
    fi; \
    # If some user already owns HOST_UID, reuse that account name; else create ${USERNAME}
    if getent passwd "${HOST_UID}" >/dev/null 2>&1; then \
      TARGET_USER_NAME="$(getent passwd "${HOST_UID}" | cut -d: -f1)"; \
      usermod -g "${HOST_GID}" "$TARGET_USER_NAME"; \
    else \
      TARGET_USER_NAME="${USERNAME}"; \
      useradd -m -s /bin/bash -u "${HOST_UID}" -g "${HOST_GID}" "$TARGET_USER_NAME"; \
    fi; \
    # Sudo for the target user
    echo "$TARGET_USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$TARGET_USER_NAME"; \
    # Record chosen user for reference
    echo "$TARGET_USER_NAME" > /etc/actual-user

# Add a tiny entrypoint that maps /var/run/docker.sock GID -> docker group for non-root usage
COPY scripts/docker-group.sh /usr/local/bin/docker-group.sh
RUN chmod +x /usr/local/bin/docker-group.sh

# Switch by numeric uid:gid to avoid name clashes across bases
USER ${HOST_UID}:${HOST_GID}
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/docker-group.sh"]
CMD ["bash"]