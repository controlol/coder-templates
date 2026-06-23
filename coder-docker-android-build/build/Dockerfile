# Android dev workspace image — BUILD ONLY (no emulator, no desktop/VNC).
# JDK 17 + Android SDK + Flutter + Node + the Claude CLI, baked in so workspaces
# start fast. enterprise-base already ships sudo, git, curl, a non-root `coder`
# user, etc. Test on a networked/physical device via `adb connect`.
FROM codercom/enterprise-base:ubuntu

# --- Versions you'll most likely want to bump over time ---------------------
ARG ANDROID_API=35
ARG BUILD_TOOLS=35.0.0
# cmdline-tools download build number (self-updates via sdkmanager afterwards).
ARG CMDLINE_TOOLS_BUILD=11076708
ARG NODE_MAJOR=24
# Pin Flutter to a concrete tag (latest 3.44 patch). Bump as new patches land.
ARG FLUTTER_VERSION=3.44.2

USER root

# --- System packages --------------------------------------------------------
# General CLI tooling. No emulator / desktop / GL libraries — this image only
# compiles and packages apps. (JDK 25 comes from the Adoptium repo below —
# Ubuntu's repos don't carry it.)
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg git unzip zip xz-utils jq ripgrep zsh \
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

# --- JDK 25 (Eclipse Temurin via the Adoptium apt repo) ---------------------
# Ubuntu's repos don't carry JDK 25; Adoptium does. Installed as the default
# JDK so Flutter/Gradle pick it up via JAVA_HOME (set below).
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo $VERSION_CODENAME) main" \
        > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends temurin-25-jdk \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js LTS + Claude CLI ----------------------------------------------
# Node is needed for the `claude` CLI (and handy for React Native later).
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

# --- SDK locations ----------------------------------------------------------
# Kept under /opt (NOT /home/coder) so image rebuilds always take effect — the
# persistent home volume mounts over /home/coder and would otherwise shadow it.
ENV JAVA_HOME=/usr/lib/jvm/temurin-25-jdk-amd64
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/flutter/bin:${PATH}"

RUN mkdir -p ${ANDROID_SDK_ROOT} ${FLUTTER_HOME} \
    && chown -R coder:coder /opt

USER coder

# --- Android SDK (no emulator / system image) -------------------------------
# platform-tools brings `adb` so you can `adb connect` to a real/networked device.
RUN curl -fsSL -o /tmp/cmdline-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip" \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
    && mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && mv /tmp/cmdline-tools/cmdline-tools/* ${ANDROID_SDK_ROOT}/cmdline-tools/latest/ \
    && rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools \
    && yes | sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --licenses >/dev/null \
    && sdkmanager --sdk_root=${ANDROID_SDK_ROOT} \
        "platform-tools" \
        "platforms;android-${ANDROID_API}" \
        "build-tools;${BUILD_TOOLS}"

# --- Flutter 3.44.x ---------------------------------------------------------
RUN git clone --depth 1 -b ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && git config --global --add safe.directory ${FLUTTER_HOME} \
    && flutter config --no-analytics --android-sdk ${ANDROID_SDK_ROOT} \
    && yes | flutter doctor --android-licenses >/dev/null 2>&1 || true \
    && flutter precache --android

ENV EDITOR=vim
