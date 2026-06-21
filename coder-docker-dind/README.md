# coder-docker-dind

A Coder template for **building and testing Docker images** — Docker-in-Docker.
Each workspace runs its **own** Docker daemon inside a privileged container, so
images and containers are isolated per workspace and nothing touches the host
daemon. Sibling of the other templates: same `enterprise-base:ubuntu` base, same
`coder-workspaces` network, same `CODER_AGENT_URL`, same per-user `claude` CLI.

## What's in the image (`build/Dockerfile`)

- **Docker CE** — engine + CLI + **Buildx** (multi-platform builds) + **Compose v2**.
- **Trivy** — scan images for CVEs.
- **hadolint** — lint Dockerfiles.
- **dive** — inspect image layers / wasted space.
- **Node LTS + Claude Code CLI** (`@anthropic-ai/claude-code`) and `pnpm`.

## How it works (DinD)

- The workspace container runs `privileged = true` (set in `main.tf`).
- `dockerd` is started in the background by the agent startup script. The
  `coder` user is in the `docker` group, so `docker ...` works without sudo.
- `/var/lib/docker` is a **dedicated volume**, so built images and the layer
  cache persist across stop/start and stay off your home volume.

```bash
docker build -t myapp .
docker compose up
docker buildx build --platform linux/amd64,linux/arm64 -t myapp .
trivy image myapp
hadolint Dockerfile
dive myapp
```

## ⚠️ Security note

Docker-in-Docker requires the container to run **privileged**, which grants
effectively full access to the host kernel. That's standard for DinD but means
this template should only be offered to trusted users. Alternatives if that's
too broad:

- **Host socket mount (DooD):** mount `/var/run/docker.sock` — lighter, but the
  workspace then shares and controls the host daemon.
- **Sysbox runtime:** unprivileged DinD via `sysbox-runc` (must be installed on
  the Docker host).

## Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| CPU cores | 4 | 2–12 |
| Memory (GB) | 6 | 2–32 |
| Git repository | — | optional, cloned on first start |

## Push the template

```bash
coder templates push docker-dind -d .
```

## Claude CLI auth

`claude` is baked in. Each user logs in once with their own Pro/Max account
(`claude` → `/login`); credentials persist in `~/.claude` on the home volume.
See the comment block in `main.tf` for the single-token alternative.
