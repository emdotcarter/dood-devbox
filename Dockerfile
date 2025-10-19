FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      gnupg \
      less \
      openssh-client \
      sudo \
      vim; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
    chmod a+r /etc/apt/keyrings/docker.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      docker-ce-cli \
      docker-compose-plugin; \
    rm -rf /var/lib/apt/lists/*

# Create (or reuse) a user with the same uid/gid as the host so the SSH socket perms work
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG USERNAME=vscode
ARG HOME_DIR=/home/${USERNAME}

# 1) Ensure there is a group with HOST_GID and call it ${USERNAME}
#    - If a group with HOST_GID already exists, rename it to ${USERNAME} (if needed)
RUN set -eux; \
    if getent group "${HOST_GID}" >/dev/null; then \
      existing_group="$(getent group "${HOST_GID}" | cut -d: -f1)"; \
      if [ "${existing_group}" != "${USERNAME}" ]; then \
        groupmod -n "${USERNAME}" "${existing_group}"; \
      fi; \
    else \
      groupadd -g "${HOST_GID}" "${USERNAME}"; \
    fi

# 2) Ensure there is a user with HOST_UID named ${USERNAME}
#    - If a user with HOST_UID exists under a different name, rename & move its home
#    - Otherwise create a fresh user
RUN set -eux; \
    if getent passwd "${HOST_UID}" >/dev/null; then \
      existing_user="$(getent passwd "${HOST_UID}" | cut -d: -f1)"; \
      if [ "${existing_user}" != "${USERNAME}" ]; then \
        usermod -l "${USERNAME}" "${existing_user}"; \
        usermod -d "/home/${USERNAME}" -m "${USERNAME}"; \
      fi; \
      usermod -s /bin/bash -g "${HOST_GID}" "${USERNAME}"; \
    else \
      useradd -m -s /bin/bash -u "${HOST_UID}" -g "${HOST_GID}" "${USERNAME}"; \
    fi; \
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}; \
    chmod 0440 /etc/sudoers.d/${USERNAME}

RUN echo "${USERNAME}" > /etc/actual-user

COPY scripts/docker-group.sh /usr/local/bin/devbox-entrypoint
RUN chmod +x /usr/local/bin/devbox-entrypoint

USER ${USERNAME}
WORKDIR /workspace

ENTRYPOINT ["devbox-entrypoint"]
CMD ["sleep", "infinity"]
