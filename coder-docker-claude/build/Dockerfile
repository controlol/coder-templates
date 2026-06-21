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

# Let the `coder` user install global npm packages without sudo.
RUN mkdir -p /usr/local/lib/node_modules /usr/local/bin \
    && chown -R coder:coder /usr/local/lib/node_modules /usr/local/bin

USER coder

# --- Claude Code CLI -------------------------------------------------------
RUN npm install -g @anthropic-ai/claude-code

# Handy global tooling. Add/remove to taste.
RUN npm install -g pnpm

# Make zsh + a sane default editor available; keep bash as login shell so the
# enterprise-base entrypoint stays happy. Users can `chsh` or set it via dotfiles.
ENV EDITOR=vim
