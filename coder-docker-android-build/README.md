# coder-docker-android-build

A **build-only** Coder template for Android app development — for writing and
compiling apps, with no emulator and no desktop/VNC. It's the lean sibling of
`coder-docker-android`: same `enterprise-base:ubuntu` base, same
`coder-workspaces` network, same `CODER_AGENT_URL`, same per-user `claude` CLI.

## What's in the image (`build/Dockerfile`)

- **JDK 17** + **Android SDK** (cmdline-tools, platform-tools, `platforms;android-35`,
  `build-tools;35.0.0`) under `/opt/android-sdk`. No emulator, no system image.
- **Flutter** (stable) under `/opt/flutter`, pre-cached for Android.
- **Node LTS + Claude Code CLI** (`@anthropic-ai/claude-code`) and `pnpm`.
- **GitHub CLI** (`gh`).

The SDK/Flutter live under `/opt` (not `/home/coder`) so image rebuilds always
take effect — the persistent home volume mounts over `/home/coder`.

## What's intentionally NOT here (vs. `coder-docker-android`)

- ❌ Android emulator + system image + AVD
- ❌ `/dev/kvm` passthrough / KVM host requirement
- ❌ XFCE desktop + KasmVNC

Result: a much smaller image, lighter workspaces, and **no host requirements** —
runs on any Docker host.

## How you work in it

- **code-server** — VS Code in the browser, with Java/Kotlin/Dart/Flutter
  extensions pre-installed.
- Build from the terminal:
  ```bash
  ./gradlew assembleDebug      # native
  flutter build apk            # Flutter
  ```
- Test on hardware via a networked device (`adb` is included):
  ```bash
  adb connect <device-ip>:5555
  ```

## Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| CPU cores | 2 | 1–8 |
| Memory (GB) | 4 | 2–16; 4+ recommended for Gradle |
| Git repository | — | optional, cloned on first start |

## Push the template

```bash
coder templates push android-build -d .
```

## Claude CLI auth

`claude` is baked in. Each user logs in once with their own Pro/Max account
(`claude` → `/login`); credentials persist in `~/.claude` on the home volume.
See the comment block in `main.tf` for the single-token alternative.
