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

# --- Claude Code CLI + handy global tooling --------------------------------
# Installed as root: NodeSource's npm uses prefix /usr, so global modules go to
# /usr/lib/node_modules and the `claude`/`pnpm` shims land in /usr/bin — on PATH
# for the coder user, no per-user chown needed.
RUN npm install -g @anthropic-ai/claude-code pnpm

USER coder

# Make zsh + a sane default editor available; keep bash as login shell so the
# enterprise-base entrypoint stays happy. Users can `chsh` or set it via dotfiles.
ENV EDITOR=vim
