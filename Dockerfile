# Base: minimal, fast; works on Apple Silicon and Intel
FROM ubuntu:24.04

ARG USERNAME=dev
ARG HOST_UID=1000
ARG HOST_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    DOCKER_BUILDKIT=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git bash zsh sudo build-essential pkg-config \
    openssh-client jq unzip less vim \
  && rm -rf /var/lib/apt/lists/*

RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && . /etc/os-release \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list \
 && apt-get update && apt-get install -y --no-install-recommends \
    docker-ce-cli docker-compose-plugin \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    if getent group "${HOST_GID}" >/dev/null 2>&1; then \
      TARGET_GRP_NAME="$(getent group "${HOST_GID}" | cut -d: -f1)"; \
    else \
      TARGET_GRP_NAME="${USERNAME}"; \
      groupadd -g "${HOST_GID}" "$TARGET_GRP_NAME"; \
    fi; \
    if getent passwd "${HOST_UID}" >/dev/null 2>&1; then \
      TARGET_USER_NAME="$(getent passwd "${HOST_UID}" | cut -d: -f1)"; \
      usermod -g "${HOST_GID}" "$TARGET_USER_NAME"; \
    else \
      TARGET_USER_NAME="${USERNAME}"; \
      useradd -m -s /bin/bash -u "${HOST_UID}" -g "${HOST_GID}" "$TARGET_USER_NAME"; \
    fi; \
    echo "$TARGET_USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$TARGET_USER_NAME"; \
    echo "$TARGET_USER_NAME" > /etc/actual-user

COPY scripts/docker-group.sh /usr/local/bin/docker-group.sh
RUN chmod +x /usr/local/bin/docker-group.sh

USER ${HOST_UID}:${HOST_GID}
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/docker-group.sh"]
CMD ["bash"]