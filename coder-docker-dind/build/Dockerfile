# Docker image build/test workspace — Docker-in-Docker (the workspace runs its
# OWN dockerd; the container is started privileged by the template).
# Ships Docker CE + buildx + compose, plus Trivy, hadolint and dive, and the
# per-user Claude CLI. enterprise-base already provides sudo, git, curl and a
# non-root `coder` user.
FROM codercom/enterprise-base:ubuntu

# --- Versions you'll most likely want to bump over time ---------------------
ARG NODE_MAJOR=24
ARG DIVE_VERSION=0.12.0

USER root

# --- Base CLI tooling -------------------------------------------------------
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg git unzip zip jq ripgrep zsh \
        iptables uidmap \
    && rm -rf /var/lib/apt/lists/*

# --- GitHub CLI (gh) via the official apt repo -----------------------------
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# --- Docker CE (engine + cli + buildx + compose) ---------------------------
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/* \
    # The docker-ce package creates the `docker` group; let `coder` use the socket.
    && usermod -aG docker coder

# --- Image test tooling: Trivy, hadolint, dive ------------------------------
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
        | sh -s -- -b /usr/local/bin \
    && curl -fsSL -o /usr/local/bin/hadolint \
        https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 \
    && chmod +x /usr/local/bin/hadolint \
    && curl -fsSL -o /tmp/dive.deb \
        "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_amd64.deb" \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/dive.deb \
    && rm -f /tmp/dive.deb

# --- Node.js LTS + Claude CLI ----------------------------------------------
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# --- Claude Code CLI (npm) + pnpm (Corepack) -------------------------------
# claude installed as root: NodeSource's npm uses prefix /usr, so the shim lands
# in /usr/bin — on PATH for the coder user. pnpm comes from Corepack (bundled
# with Node); COREPACK_HOME is a shared path so the coder user finds the cached
# pnpm at runtime without a re-download.
ENV COREPACK_HOME=/opt/corepack
RUN npm install -g @anthropic-ai/claude-code \
    && corepack enable \
    && corepack prepare pnpm@latest --activate \
    && chmod -R a+rX "$COREPACK_HOME"

USER coder

ENV EDITOR=vim
