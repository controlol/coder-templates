# Android dev workspace image. The Android SDK, an AVD, Flutter, an XFCE
# desktop (for KasmVNC), Node + the Claude CLI are all baked in so workspaces
# start fast. enterprise-base already ships sudo, git, curl, a non-root `coder`
# user, etc.
FROM codercom/enterprise-base:ubuntu

# --- Versions you'll most likely want to bump over time ---------------------
ARG ANDROID_API=35
ARG BUILD_TOOLS=35.0.0
ARG SYSTEM_IMAGE="system-images;android-35;google_apis;x86_64"
ARG AVD_DEVICE="pixel_6"
ARG AVD_NAME="pixel_api35"
# cmdline-tools download build number (self-updates via sdkmanager afterwards).
ARG CMDLINE_TOOLS_BUILD=11076708
ARG NODE_MAJOR=24
# Pin Flutter to a concrete tag (latest 3.44 patch). Bump as new patches land.
ARG FLUTTER_VERSION=3.44.2

USER root

# --- System packages --------------------------------------------------------
# An XFCE desktop for the KasmVNC module, the emulator's runtime libraries, and
# general CLI tooling. (JDK 25 comes from the Adoptium repo below — Ubuntu's
# repos don't carry it.)
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg git unzip zip xz-utils jq ripgrep zsh \
        # XFCE desktop (rendered through KasmVNC in the browser)
        xfce4 xfce4-terminal dbus-x11 x11-utils \
        # Android emulator GUI / audio / GL runtime deps
        libgl1 libpulse0 libnss3 libxcomposite1 libxcursor1 libxi6 libxtst6 \
        libasound2 libdbus-1-3 libx11-xcb1 \
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
ENV PATH="/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:/opt/flutter/bin:${PATH}"

RUN mkdir -p ${ANDROID_SDK_ROOT} ${FLUTTER_HOME} \
    && chown -R coder:coder /opt

USER coder

# --- Android SDK + a ready-to-run AVD ---------------------------------------
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
        "build-tools;${BUILD_TOOLS}" \
        "emulator" \
        "${SYSTEM_IMAGE}" \
    && echo "no" | avdmanager --clear-cache create avd \
        -n "${AVD_NAME}" -k "${SYSTEM_IMAGE}" -d "${AVD_DEVICE}" --force

# Software GPU so the emulator renders inside the headless KasmVNC desktop.
RUN printf '\nhw.gpu.enabled=yes\nhw.gpu.mode=swiftshader_indirect\n' \
        >> "$HOME/.android/avd/${AVD_NAME}.avd/config.ini"

# --- Flutter 3.44.x ---------------------------------------------------------
RUN git clone --depth 1 -b ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && git config --global --add safe.directory ${FLUTTER_HOME} \
    && flutter config --no-analytics --android-sdk ${ANDROID_SDK_ROOT} \
    && yes | flutter doctor --android-licenses >/dev/null 2>&1 || true \
    && flutter precache --android

ENV EDITOR=vim
