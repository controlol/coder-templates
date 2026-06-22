# coder-docker-android

A Coder template for **Android app development** (native Kotlin/Java + Flutter),
built as a sibling of the `coder-docker-claude` (node) template — same
`enterprise-base:ubuntu` base, same `coder-workspaces` network, same
`CODER_AGENT_URL`, and the same per-user `claude` CLI baked into the image.

## What's in the image (`build/Dockerfile`)

- **JDK 17** + **Android SDK** (cmdline-tools, platform-tools, `platforms;android-35`,
  `build-tools;35.0.0`, `emulator`) under `/opt/android-sdk`.
- A ready-to-run **AVD** (`pixel_api35`, Pixel 6, `google_apis;x86_64`),
  configured for software GL (`swiftshader_indirect`) so it renders headless.
- **Flutter** (stable) under `/opt/flutter`, pre-cached for Android.
- **Node LTS + Claude Code CLI** (`@anthropic-ai/claude-code`) and `pnpm`.
- **GitHub CLI** (`gh`).
- **XFCE** desktop for the KasmVNC browser desktop.

The SDK/Flutter live under `/opt` (not `/home/coder`) so image rebuilds always
take effect — the persistent home volume mounts over `/home/coder`. The AVD is
created in `~/.android` so it persists across stop/start.

## How you work in it

- **code-server** — VS Code in the browser, with Java/Kotlin/Dart/Flutter
  extensions pre-installed.
- **KasmVNC** — a browser XFCE desktop. Run Android Studio's GUI here, or view
  the emulator screen. Launch an emulator from a terminal:
  ```bash
  emulator -avd pixel_api35 -gpu swiftshader_indirect &
  ```
- Build from the terminal: `./gradlew assembleDebug` or `flutter run`.

## ⚠️ Host requirement: KVM

The "Hardware-accelerated emulator (KVM)" parameter passes `/dev/kvm` from the
Docker **host** into the workspace. The host must expose `/dev/kvm`:

- bare-metal Linux, **or**
- a VM with **nested virtualization** enabled.

If your host has no `/dev/kvm`, **turn the parameter off** — the workspace still
builds with Gradle/Flutter and can test on a networked device via
`adb connect <ip>:5555`. With it off, an emulator started in the workspace runs
without acceleration (slow).

> If `enable_kvm` is on but the host lacks `/dev/kvm`, container creation fails.
> That's intentional — flip the parameter off for non-KVM hosts.

## Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| CPU cores | 4 | 2–12 |
| Memory (GB) | 8 | 4–32; 8+ recommended with the emulator |
| Hardware-accelerated emulator (KVM) | true | needs `/dev/kvm` on the host |
| Git repository | — | optional, cloned on first start |

## Push the template

```bash
coder templates push android -d .
```

## Claude CLI auth

`claude` is baked in. Each user logs in once with their own Pro/Max account
(`claude` → `/login`); credentials persist in `~/.claude` on the home volume.
See the comment block in `main.tf` for the single-token alternative.
