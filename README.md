# DeepSeek Harness Android (DSHA)

## 中文说明 / Chinese Overview

DeepSeek Harness Android（DSHA）是一套开源的远程控制套件：用一个安卓原生客户端
连接自托管的 DeepSeek Harness，支持连接设备、插件市场、工作区选择、命令执行、
VNC 图形远控电脑、DSHA 实时手机画面，以及陀螺仪视差动效和鲸鱼粒子开屏动画。

完整中文文档见 [README.zh-CN.md](README.zh-CN.md)，详细操作手册见
[docs/OPERATION_MANUAL.zh-CN.md](docs/OPERATION_MANUAL.zh-CN.md)。
iOS 版本源码见 [ios/README.md](ios/README.md)。

---

An open-source remote-control suite that connects an Android phone to a
self-hosted **DeepSeek Harness** instance. It provides a native Android client,
a macOS desktop window, a local/remote API bridge, and a harness plugin that
launches a live phone screen.

> Chinese version: [README.zh-CN.md](README.zh-CN.md)
> Detailed step-by-step manual: [docs/OPERATION_MANUAL.md](docs/OPERATION_MANUAL.md)

## What it does

- **Android client** (`android/`): a landscape-first WebView that loads the
  DeepSeek Harness web UI, wrapped in a native control drawer. It can:
  - connect to any Harness server (LAN or public tunnel),
  - browse/install Harness plugins from npm,
  - add a workspace from the phone's local files (upload to the computer) or
    from a remote device's filesystem,
  - list devices logged into Harness and control them (command execution),
  - graphically remote-control the Mac desktop over VNC (noVNC),
  - apply a gyroscope-driven parallax effect to the web UI,
  - show a light-particle "DeepSeek whale" splash animation,
  - use rounded, Harness-styled dialogs instead of native Android dialogs.
- **macOS desktop window** (`desktop/`): a Swift `WKWebView` app that owns its
  own `dsh web` server, shows the DeepSeek API balance, and adds a **DSHA**
  menu item that launches `scrcpy` to view/control the connected phone.
- **iOS client** (`ios/`): a SwiftUI port of the Android client (WebView +
  native drawer, plugin marketplace, device control, VNC, gyroscope parallax,
  and particle splash).
- **API bridge** (`server/remote-api.cjs`): a small Node HTTP server exposing
  `/health`, `/devices`, `/plugins`, `/install`, `/upload`, and `/exec`.
- **LAN relay** (`server/lan-relay.cjs`): a TCP forwarder that lets the phone
  reach the Harness on the local network (Harness itself refuses `0.0.0.0`).
- **Harness plugin** (`plugins/dsh-dsha/`): a `dsh` bundle that registers the
  `/dsha` command inside the Harness composer to launch `scrcpy`.
- **Service configs** (`launchd/`, `launchers/`): launchd agents and CLI
  wrappers that keep the servers and Cloudflare tunnels running.

## Repository layout

```text
.
├── android/
│   ├── app/                         Android application source
│   │   ├── AndroidManifest.xml
│   │   ├── src/com/deepseek/harness/android/
│   │   │   ├── MainActivity.java    native drawer + WebView + sensors
│   │   │   ├── VncActivity.java     full-screen noVNC remote desktop
│   │   │   ├── ParticleSplashView.java
│   │   │   └── RemoteApi.java       HTTP helpers for the bridge
│   │   ├── res/                     resources (adaptive DeepSeek whale icon)
│   │   └── assets/whale.png         splash target bitmap
│   ├── build-apk.sh                 builds the APK without Gradle
│   └── make-icons.cjs               generates launcher icons with sharp
├── desktop/
│   ├── DSHWindow.swift              macOS WKWebView window + balance + DSHA
│   ├── start-server.sh              owns/start the app's dsh web instance
│   └── build-window.sh              swiftc rebuild + ad-hoc codesign
├── ios/
│   ├── README.md                    iOS build instructions (bilingual)
│   └── DSHA/                        SwiftUI source
├── server/
│   ├── remote-api.cjs               device/plugin/upload/exec bridge
│   └── lan-relay.cjs                TCP forwarder for LAN access
├── plugins/
│   └── dsh-dsha/                    Harness plugin: /dsha -> scrcpy
├── launchd/                         macOS LaunchAgents (persistent services)
├── launchers/
│   ├── dsh                          dsh wrapper (telemetry off + heap cap)
│   └── dsh-url                      prints current LAN + public URLs
└── docs/
    └── OPERATION_MANUAL.md          detailed manual
```

## Requirements

### Desktop (macOS)

- Node.js 22+ (recommended 24)
- `pnpm`
- Android platform-tools (`adb`) for the phone-control features
- `scrcpy` 4.x for the DSHA live phone screen
- `cloudflared` for public cross-network tunnels
- Xcode command line tools (`swiftc`, `xcrun`) to rebuild the desktop window

### Android build (only needed to rebuild the APK)

- JDK 17
- Android SDK command line tools + `build-tools;35.0.0` + `platforms;android-35`
- `sharp` (via Node) to regenerate the launcher icon

### VNC remote desktop (phone -> Mac)

- macOS **Screen Sharing** enabled (VNC on port 5900)
- `python3` + `websockify` + `noVNC`

## Quick start

See [docs/OPERATION_MANUAL.md](docs/OPERATION_MANUAL.md) for the full
step-by-step guide. The short version:

```bash
# 1. Install the desktop prerequisites.
# 2. Build and install the Android APK:
./android/build-apk.sh
adb install -r android/DeepSeek-harness-android.apk
# 3. Start the bridge + LAN relay + tunnels:
launchctl load launchd/*.plist
# 4. Point the phone app at the printed URL:
dsh-url
```

## Security notes

- The Harness web server refuses to bind `0.0.0.0` by design; the LAN relay is
  the intended way to expose it on the local network.
- `/exec` on `remote-api.cjs` is **arbitrary shell execution** on the Mac.
  Only expose it through a tunnel URL you keep private.
- Cloudflare **quick tunnels** have no uptime guarantee and the URL changes on
  restart. Use named tunnels or Tailscale for anything long-lived.
- The VNC password is passed in the noVNC URL for convenience. Prefer entering
  it manually if the URL could be shared.

## License

MIT — see [LICENSE](LICENSE).

DeepSeek and the DeepSeek whale logo are trademarks of DeepSeek / Hangzhou
DeepSeek AI. This project is an unofficial community integration and is not
affiliated with or endorsed by DeepSeek.
