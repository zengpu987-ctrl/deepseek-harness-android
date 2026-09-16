# DSHA 操作手册

本手册覆盖在 macOS 上用安卓手机安装、构建、连接和操作 DSHA 的全部组件。

> English: [OPERATION_MANUAL.md](OPERATION_MANUAL.md)

## 1. 架构

```text
                         ┌──────────────────────────────┐
                         │          安卓手机            │
                         │  MainActivity（WebView+UI）  │
                         │  VncActivity（noVNC）        │
                         └──────────────┬───────────────┘
                                        │  HTTPS（Cloudflare 快速隧道）
               ┌────────────────────────┼────────────────────────┐
               │                        │                        │
    ┌──────────▼───────────┐  ┌─────────▼──────────┐  ┌──────────▼──────────┐
    │ DeepSeek Harness     │  │ remote-api.cjs    │  │ noVNC + websockify  │
    │ dsh web（127.0.0.1） │  │ 127.0.0.1:3090    │  │ 127.0.0.1:6900      │
    │ 3081                 │  └─────────┬──────────┘  └─────────┬──────────┘
    └──────────┬───────────┘            │                        │
               │ lan-relay 3082         │                        │
               └────────────────────────┴────────────────────────┘
                              macOS 主机
```

Harness 网页服务只绑定 `127.0.0.1`，其余都是本地桥接，再通过 Cloudflare
隧道暴露到公网。

## 2. 桌面端依赖

```bash
# Node.js（用于桥接、中继和 dsh 本身）
curl -fsSL https://nodejs.org/dist/v24.19.0/node-v24.19.0-darwin-arm64.tar.gz | tar -xz

# pnpm
npm install -g pnpm

# Android platform-tools（adb）
curl -fsSL https://dl.google.com/android/repository/platform-tools-latest-darwin.zip -o /tmp/pt.zip
unzip /tmp/pt.zip -d ~/android-sdk

# scrcpy（实时手机画面）
# 从 https://github.com/Genymobile/scrcpy/releases 下载，把 scrcpy 和 scrcpy-server 放入 PATH。

# cloudflared（公网隧道）
# 从 https://github.com/cloudflare/cloudflared/releases 下载并放入 PATH。
```

确认 `node`、`pnpm`、`adb`、`scrcpy`、`cloudflared` 都在 `PATH` 中。

## 3. 安装 DeepSeek Harness

```bash
npm install -g @deepseek-ai/dsh
dsh web --no-open        # 首次启动，确认能正常运行
```

DSHA 假设 Harness 的 web profile 位于 `~/.dsh/profiles/web`。加入 DSHA 插件，
让输入框暴露 `/dsha` 命令：

```bash
dsh plugin --profile web add file:/绝对路径/dsha/plugins/dsh-dsha
```

添加插件后重启 Harness。

## 4. 安装桥接与中继

```bash
mkdir -p ~/.dsh
cp server/remote-api.cjs ~/.dsh/remote-api.cjs
cp server/lan-relay.cjs ~/.dsh/lan-relay.cjs
```

安装提供的 LaunchAgents：

```bash
for f in launchd/*.plist; do
  cp "$f" ~/Library/LaunchAgents/
  launchctl load "$f"
done
```

这会常驻启动：

- `lan-relay`：`0.0.0.0:3082 -> 127.0.0.1:3081`
- `remote-api`：`127.0.0.1:3090`
- 三个 Cloudflare 隧道，分别对应 3081、3090、6900

## 5. 构建并安装安卓 APK

要求：JDK 17、Android `build-tools;35.0.0`、`platforms;android-35`。

```bash
export JAVA_HOME=/path/to/jdk17
export ANDROID_HOME=/path/to/android-sdk
./android/build-apk.sh
adb install -r android/DeepSeek-harness-android.apk
```

构建脚本直接使用 `aapt2`、`javac`、`d8`、`zipalign`、`apksigner`（无需
Gradle）。

## 6. 连接手机

获取当前地址：

```bash
dsh-url
# LAN:  http://192.168.x.x:3082/?token=...
# 公网: https://xxxx.trycloudflare.com/?token=...
```

在手机上点左上角 `☰` 打开抽屉，在「连接设备」输入地址，点「连接」。应用会
记住该地址。

> Harness 每次重启 `token` 都会变。重启后重新运行 `dsh-url`，把新地址粘贴进去。

## 7. 安卓抽屉功能

### 7.1 添加工作区

- 「安卓手机内部文件」打开安卓文件选择器（多选），把文件上传到电脑的
  `~/dsh-android-workspace/`。
- 「远端设备文件」打开 Harness 网页端自带的工作区选择器（浏览 Mac 文件系统）。

### 7.2 插件市场

- 在「远程服务 / 插件市场」填入桥接地址。
- 点「浏览插件市场」列出 npm `dsh-plugin` 包。
- 点「安装 <名字>」在电脑端执行 `dsh plugin --profile web add <名字>`。

### 7.3 控制已登录设备

- 点「控制已登录设备」从 `GET /devices` 列出设备。
- 选中设备后打开命令控制台，通过 `POST /exec` 在该设备上执行命令并显示输出。

### 7.4 图形远控（手机 -> Mac）

前置：macOS 开启「屏幕共享」（系统设置 → 通用 → 共享 → 屏幕共享）并设置
VNC 密码，同时安装 `websockify` + `noVNC`：

```bash
python3 -m venv ~/novnc/venv
~/novnc/venv/bin/pip install websockify
~/novnc/venv/bin/websockify --web /path/to/noVNC 6900 127.0.0.1:5900
```

然后点「图形远控电脑」，输入 VNC 密码，点「连接并操控电脑」。应用会打开全屏
noVNC 客户端并自动连接。

## 8. DSHA 实时手机画面（Mac -> 手机）

手机用 USB 连接并开启 USB 调试后：

- 在 macOS 桌面应用菜单中选择 **DSHA（远控安卓手机）**，或
- 在 Harness 输入框输入 `/dsha`。

这会启动 `scrcpy`，在新窗口显示手机实时画面，鼠标键盘输入会转发到手机。

## 9. 重编译桌面窗口

编辑 `desktop/DSHWindow.swift`，然后：

```bash
desktop/build-window.sh
```

该脚本执行 `xcrun swiftc`，ad-hoc 重签名并安装新二进制。

## 10. 常见问题

- **手机显示“Reconnecting…”或 403**：Harness 重启导致 token 变化。运行
  `dsh-url` 用新地址重连。
- **抽屉按钮被截断**：抽屉是 `ScrollView`，上下滑动即可。
- **插件市场被遮挡**：点「插件市场」会切竖屏获得更高视口；按返回键切回横屏。
- **VNC 黑屏**：确认屏幕共享已开、5900 端口监听、VNC 密码正确。
- **快速隧道域名解析失败**：重启隧道；快速隧道子域名偶发需要时间传播。

## 11. 安全

`remote-api.cjs` 的接口默认无鉴权（仅靠隧道地址保密）。若公开暴露，请加 API
令牌或放到 VPN 后面。`/exec` 是任意 shell 执行，必须按远程代码执行面看待。
