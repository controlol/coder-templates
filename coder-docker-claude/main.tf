terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

# ---------------------------------------------------------------------------
# Providers & data sources
# ---------------------------------------------------------------------------

variable "docker_socket" {
  default     = ""
  description = "(Optional) Docker socket URI, e.g. unix:///var/run/docker.sock"
  type        = string
}

provider "docker" {
  # Use the value from the variable if set, otherwise the provider default.
  host = var.docker_socket != "" ? var.docker_socket : null
}

provider "coder" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# ---------------------------------------------------------------------------
# Workspace parameters (shown in the "create workspace" form)
# ---------------------------------------------------------------------------

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU cores"
  description  = "Number of CPU cores"
  default      = "2"
  type         = "number"
  icon         = "/icon/memory.svg"
  mutable      = true
  order        = 1
  validation {
    min = 1
    max = 8
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Amount of memory in GB"
  default      = "2"
  type         = "number"
  icon         = "/icon/memory.svg"
  mutable      = true
  order        = 2
  validation {
    min = 1
    max = 16
  }
}

data "coder_parameter" "repo_url" {
  name         = "repo_url"
  display_name = "Git repository"
  description  = "(Optional) A git repo to clone into the workspace on first start"
  default      = ""
  type         = "string"
  icon         = "/icon/git.svg"
  mutable      = true
  order        = 3
}

# ---------------------------------------------------------------------------
# Coder agent — this is what makes SSH / web terminal / apps work
# ---------------------------------------------------------------------------

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  # SSH, the web terminal, and port-forwarding are provided automatically by
  # the agent. display_apps controls which built-ins show on the dashboard.
  display_apps {
    vscode          = true # "Open in VS Code Desktop" (Remote-SSH)
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = true # `coder ssh` / `coder config-ssh`
    port_forwarding_helper = true
  }

  startup_script_behavior = "blocking"
  startup_script          = <<-EOT
    set -e

    # Personalize the box with your dotfiles repo (optional, see below).

    # Clone the requested repo on first start if the dir isn't there yet.
    if [ -n "${data.coder_parameter.repo_url.value}" ]; then
      dir="$HOME/$(basename "${data.coder_parameter.repo_url.value}" .git)"
      if [ ! -d "$dir" ]; then
        git clone "${data.coder_parameter.repo_url.value}" "$dir" || true
      fi
    fi
  EOT

  # These become git's identity inside the workspace.
  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  # Live stats on the workspace dashboard.
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $HOME"
    interval     = 60
    timeout      = 1
  }
}

# ---------------------------------------------------------------------------
# Modules from the Coder Registry — the easy way to add tooling
# ---------------------------------------------------------------------------

# code-server: VS Code in the browser.
module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "1.5.0"
  agent_id = coder_agent.main.id
  order    = 1

  # Pre-install some extensions from OpenVSX.
  extensions = [
    "anthropic.claude-code",
  ]
}

# Claude CLI authentication: PER-USER (option 1).
#
# The `claude` CLI is baked into the image (see build/Dockerfile). Each user logs
# in with their OWN Pro/Max subscription, once, inside the workspace:
#
#     claude        # then /login -> open the OAuth URL locally, paste the code back
#
# Credentials land in ~/.claude, which sits on the persistent home volume below,
# so the login survives stop/start — users authenticate only once per workspace.
#
# The claude-code REGISTRY MODULE is intentionally NOT used here: it's built
# around a single shared token (CLAUDE_CODE_OAUTH_TOKEN) + a Coder Task app,
# which is the single-user model. Sharing one subscription token across users
# violates Anthropic's terms. If you run a personal/solo deployment and want the
# Task dashboard + auto-auth instead, uncomment the block below and pass a token
# from `claude setup-token`:
#
# variable "anthropic_oauth_token" {
#   type = string ; default = "" ; sensitive = true
# }
# module "claude-code" {
#   count                   = data.coder_workspace.me.start_count
#   source                  = "registry.coder.com/coder/claude-code/coder"
#   version                 = "5.2.0"
#   agent_id                = coder_agent.main.id
#   workdir                 = "/home/coder"
#   order                   = 2
#   claude_code_oauth_token = var.anthropic_oauth_token
#   model                   = "sonnet"
# }

# git-clone is an alternative to the startup-script clone above if you prefer a
# module. Left commented to avoid double-cloning.
# module "git-clone" {
#   count    = data.coder_parameter.repo_url.value != "" ? data.coder_workspace.me.start_count : 0
#   source   = "registry.coder.com/coder/git-clone/coder"
#   version  = "2.0.1"
#   agent_id = coder_agent.main.id
#   url      = data.coder_parameter.repo_url.value
# }

# dotfiles: lets each user personalize their box from a dotfiles repo.
module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/dotfiles/coder"
  version  = "1.4.2"
  agent_id = coder_agent.main.id
}

# ---------------------------------------------------------------------------
# Docker resources
# ---------------------------------------------------------------------------

# Build the image from ./build/Dockerfile so Node LTS + Claude CLI are baked in.
resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}"
  build {
    context = "./build"
    tag     = ["coder-${data.coder_workspace.me.id}:latest"]
  }
  # Rebuild when the Dockerfile changes.
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

# Persistent home — survives stop/start and template updates.
resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  # Protect the volume from accidental deletion due to changing attributes.
  lifecycle {
    ignore_changes = all
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.main.name
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  # Hostname makes the shell prompt show the workspace name.
  hostname = data.coder_workspace.me.name

  # Resource limits from the workspace parameters.
  cpu_shares = data.coder_parameter.cpu.value * 1024
  memory     = data.coder_parameter.memory.value * 1024

  # Use the docker gateway if the access URL is 127.0.0.1.
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "CODER_AGENT_URL=http://docker.coder-agent.junomedia.nl:7080",
  ]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }

  networks_advanced {
    name = "coder-workspaces"
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
