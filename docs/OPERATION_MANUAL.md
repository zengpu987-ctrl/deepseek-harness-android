# DSHA Operation Manual

This manual covers installing, building, connecting, and operating every
component of DSHA on macOS with an Android phone.

> 中文手册：[OPERATION_MANUAL.zh-CN.md](OPERATION_MANUAL.zh-CN.md)

## 1. Architecture

```text
                         ┌──────────────────────────────┐
                         │        Android phone         │
                         │  MainActivity (WebView+UI)   │
                         │  VncActivity (noVNC)         │
                         └──────────────┬───────────────┘
                                        │  HTTPS (Cloudflare quick tunnel)
               ┌────────────────────────┼────────────────────────┐
               │                        │                        │
    ┌──────────▼───────────┐  ┌─────────▼──────────┐  ┌──────────▼──────────┐
    │ DeepSeek Harness     │  │ remote-api.cjs    │  │ noVNC + websockify  │
    │ dsh web (127.0.0.1)  │  │ 127.0.0.1:3090    │  │ 127.0.0.1:6900      │
    │ 3081                 │  └─────────┬──────────┘  └─────────┬──────────┘
    └──────────┬───────────┘            │                        │
               │ lan-relay 3082         │                        │
               └────────────────────────┴────────────────────────┘
                              macOS host
```

The Harness web server binds to `127.0.0.1` only. Everything else is a local
bridge that is exposed through Cloudflare tunnels.

## 2. Desktop prerequisites

```bash
# Node.js (used for the bridge, relay, and dsh itself)
curl -fsSL https://nodejs.org/dist/v24.19.0/node-v24.19.0-darwin-arm64.tar.gz | tar -xz

# pnpm
npm install -g pnpm

# Android platform-tools (adb)
curl -fsSL https://dl.google.com/android/repository/platform-tools-latest-darwin.zip -o /tmp/pt.zip
unzip /tmp/pt.zip -d ~/android-sdk

# scrcpy (live phone screen)
# Download from https://github.com/Genymobile/scrcpy/releases and put scrcpy + scrcpy-server on PATH.

# cloudflared (public tunnels)
# Download from https://github.com/cloudflare/cloudflared/releases and put it on PATH.
```

Make sure `node`, `pnpm`, `adb`, `scrcpy`, and `cloudflared` are all on `PATH`.

## 3. Install DeepSeek Harness

```bash
npm install -g @deepseek-ai/dsh
dsh web --no-open        # first launch, confirm it starts
```

DSHA expects the Harness web profile to be at `~/.dsh/profiles/web`. Add the
DSHA plugin so the composer exposes `/dsha`:

```bash
dsh plugin --profile web add file:/absolute/path/to/dsha/plugins/dsh-dsha
```

Restart the Harness after adding plugins.

## 4. Install the bridge and relay

```bash
mkdir -p ~/.dsh
cp server/remote-api.cjs ~/.dsh/remote-api.cjs
cp server/lan-relay.cjs ~/.dsh/lan-relay.cjs
```

Install the provided LaunchAgents:

```bash
for f in launchd/*.plist; do
  cp "$f" ~/Library/LaunchAgents/
  launchctl load "$f"
done
```

This starts (and keeps alive):

- `lan-relay` on `0.0.0.0:3082 -> 127.0.0.1:3081`
- `remote-api` on `127.0.0.1:3090`
- three Cloudflare tunnels for ports 3081, 3090, and 6900

## 5. Build and install the Android APK

Requirements: JDK 17, Android `build-tools;35.0.0`, `platforms;android-35`.

```bash
export JAVA_HOME=/path/to/jdk17
export ANDROID_HOME=/path/to/android-sdk
./android/build-apk.sh
adb install -r android/DeepSeek-harness-android.apk
```

The build script uses `aapt2`, `javac`, `d8`, `zipalign`, and `apksigner`
directly (no Gradle).

## 6. Connect the phone

Get the current addresses:

```bash
dsh-url
# LAN:  http://192.168.x.x:3082/?token=...
# 公网: https://xxxx.trycloudflare.com/?token=...
```

On the phone, open the drawer (top-left `☰`), enter the URL under
「连接设备」, and tap 「连接」. The app stores it for next launch.

> The `token` changes every time the Harness restarts. Run `dsh-url` again
> after a restart and paste the new address.

## 7. Android drawer features

### 7.1 Add workspace

- 「安卓手机内部文件」 opens the Android document picker (multi-select) and
  uploads the files to the Mac's `~/dsh-android-workspace/`.
- 「远端设备文件」 opens the Harness web UI's own workspace picker (browse the
  Mac filesystem).

### 7.2 Plugin marketplace

- Enter the bridge URL in 「远程服务 / 插件市场」.
- Tap 「浏览插件市场」 to list npm `dsh-plugin` packages.
- Tap 「安装 <name>」 to run `dsh plugin --profile web add <name>` on the Mac.

### 7.3 Control a logged-in device

- Tap 「控制已登录设备」 to list devices from `GET /devices`.
- Selecting a device opens a command console that runs `POST /exec` on that
  device and shows the output.

### 7.4 Graphical remote control (phone -> Mac)

Prerequisite: macOS **Screen Sharing** enabled (System Settings → General →
Sharing → Screen Sharing) with a VNC password, plus `websockify` + `noVNC`:

```bash
python3 -m venv ~/novnc/venv
~/novnc/venv/bin/pip install websockify
~/novnc/venv/bin/websockify --web /path/to/noVNC 6900 127.0.0.1:5900
```

Then tap 「图形远控电脑」, enter the VNC password, and tap 「连接并操控电脑」.
The app opens a full-screen noVNC client and auto-connects.

## 8. DSHA live phone screen (Mac -> phone)

With the phone connected over USB and USB debugging enabled:

- In the macOS desktop app menu, choose **DSHA（远控安卓手机）**, or
- In the Harness composer, type `/dsha`.

This launches `scrcpy` in a new window showing the phone's live screen; mouse
and keyboard input are forwarded to the phone.

## 9. Rebuilding the desktop window

Edit `desktop/DSHWindow.swift`, then:

```bash
desktop/build-window.sh
```

This runs `xcrun swiftc`, re-signs the app ad-hoc, and installs the new binary.

## 10. Troubleshooting

- **Phone shows "Reconnecting..." / 403**: the Harness was restarted and the
  token changed. Run `dsh-url` and reconnect with the new address.
- **Buttons in the drawer are cut off**: scroll the drawer; it is a `ScrollView`.
- **Marketplace is occluded**: tapping 「插件市场」 switches to portrait for a
  taller viewport; press Back to return to landscape.
- **VNC black screen**: confirm Screen Sharing is on, port 5900 is listening,
  and the VNC password is correct.
- **Quick tunnel URL does not resolve**: restart the tunnel; quick-tunnel
  subdomains occasionally take time to propagate.

## 11. Security

`remote-api.cjs` endpoints are intentionally unauthenticated (protected only by
the secrecy of the tunnel URL). If you expose them publicly, add an API token or
put them behind a VPN. `/exec` is arbitrary shell execution and must be treated
as a remote-code-execution surface.
