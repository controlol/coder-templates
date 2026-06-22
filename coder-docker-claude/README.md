---
display_name: Docker (Node 26 + Claude Code)
description: Docker workspaces with SSH, code-server, Node.js LTS, and the Claude CLI.
icon: ../../../site/static/icon/docker.png
maintainer_github: web-fuse
tags: [docker, node, claude, code-server]
---

# Docker · Node LTS · Claude Code

A self-contained [Coder](https://github.com/coder/coder) template that runs each
workspace as a Docker container with:

- **SSH** + web terminal (built into the Coder agent)
- **code-server** (VS Code in the browser)
- **Node.js 26** (Current line; baked into the image — set `NODE_MAJOR=24` for Active LTS)
- **Claude Code CLI** (`claude`, baked into the image)
- **GitHub CLI** (`gh`, baked into the image)
- A **persistent `/home/coder` volume** that survives stop/start
- **dotfiles** support so each user can personalize their box

## Prerequisites

A running Coder deployment whose provisioner can reach a Docker daemon
(the simplest setup runs Coder on the same host with the Docker socket mounted).

## Push the template

```bash
# from this directory
coder templates push docker-node-claude -d .
```

Then create a workspace from the Coder dashboard (or `coder create`).

## Connecting

```bash
coder config-ssh                 # writes ~/.ssh/config entries
ssh coder.<workspace-name>       # plain SSH
coder ssh <workspace-name>       # or via the CLI

# code-server opens from the workspace dashboard, or:
coder port-forward <workspace> --tcp 13337:13337
```

## Claude authentication (per-user subscription)

The `claude` CLI is baked into the image for everyone. Each user signs in with
**their own Claude Pro/Max subscription**, once, inside the workspace:

```bash
claude        # then run /login
              # opens an OAuth URL — complete it in your local browser,
              # then paste the code back into the terminal
```

This uses your subscription (an `sk-ant-oat01-…` OAuth token), **not** pay-per-token
API billing. Credentials are stored in `~/.claude`, which lives on the persistent
home volume — so the login survives stop/start and you only do it once per workspace.

> **Note:** This template deliberately does *not* bake in a shared token. Sharing a
> single subscription across multiple users violates Anthropic's terms. For a
> personal/solo deployment that wants auto-auth + the Coder Task dashboard, see the
> commented `claude-code` module in [`main.tf`](main.tf) and `claude setup-token`.

## Customizing

- **Node version** — change `NODE_MAJOR` in [`build/Dockerfile`](build/Dockerfile). Set to `26` (Current) or `24` (Active LTS).
- **Extra tooling** — add `apt-get` / `npm install -g` lines to the Dockerfile so
  it's baked in (fast start) rather than installed at runtime.
- **Editor extensions** — edit the `extensions` list on the `code-server` module.
- **CPU / memory / repo** — exposed as workspace parameters in `main.tf`.

---

## What else people add to improve remote coding

Below are common upgrades, roughly in order of bang-for-buck. The ones marked
✅ are already in this template.

### Workflow & ergonomics
- ✅ **Persistent home volume** so `node_modules`, shell history, and clones survive restarts.
- ✅ **dotfiles module** — each user's shell, aliases, tmux/nvim config applied automatically.
- ✅ **code-server** for browser VS Code; add **JetBrains Gateway** (`jetbrains-gateway` module) or **Cursor** (`cursor` module) if your team uses them.
- **VS Code Desktop via Remote-SSH** (already enabled through `display_apps.vscode`) — many prefer the native client over the browser.
- **tmux / zsh + starship** baked into the image so sessions survive dropped SSH connections.
- **mutagen or `coder` SSH file sync** for fast bidirectional file sync when editing locally.

### Speed
- **Prebuilds** (`coder_workspace_preset` + prebuilt pools) so a warm workspace is waiting — no cold start.
- **Bake tools into the image** (this template does) instead of installing in `startup_script`.
- **Cache mounts** — a shared Docker volume for `~/.npm`, `~/.cache`, pnpm store across rebuilds.
- Pin `code-server` / module versions and use `use_cached = true` to skip re-downloads.

### Claude / AI coding
- **Coder Tasks** — the (commented-out) `claude-code` module registers a Task app to drive the agent from the dashboard; it needs a shared token, so it's off by default in favor of per-user login.
- **MCP servers** — pass `mcp_servers` to the `claude-code` module to wire in tools (GitHub, Playwright, your DB) at user scope.
- **Pre-seed `CLAUDE.md`** and an allowlist via dotfiles so the agent has project context and fewer permission prompts.

### Capability
- **Docker-in-Docker** — mount the Docker socket or run a DinD sidecar if workspaces need to build/run containers.
- **GPU passthrough** for ML work (`gpus = "all"` on the container + NVIDIA runtime).
- **More resources / parameters** — expose disk size, region, or image choice as `coder_parameter`s.
- **Git provider integration** — `coder_external_auth` for GitHub/GitLab so clones and the CLI are authenticated without manual token paste.

### Security & ops
- **Resource limits** (✅ CPU/memory params) and **idle auto-stop** (`coder_workspace` TTL settings).
- **Network policies / egress controls** if running untrusted code or AI agents.
- **Workspace tags & quotas** to control where/how many workspaces run.
