# Bake the toolchain into the image so workspaces start fast.
# enterprise-base already ships sudo, git, curl, a non-root `coder` user, etc.
FROM codercom/enterprise-base:ubuntu

ARG NODE_MAJOR=26

USER root

# --- System packages -------------------------------------------------------
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        build-essential \
        gnupg \
        jq \
        ripgrep \
        unzip \
        zsh \
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

# --- Node.js LTS via NodeSource -------------------------------------------
# NODE_MAJOR=26 is the latest "Current" line (LTS in Oct 2026). Use 24 for Active LTS.
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

# Make zsh + a sane default editor available; keep bash as login shell so the
# enterprise-base entrypoint stays happy. Users can `chsh` or set it via dotfiles.
ENV EDITOR=vim
