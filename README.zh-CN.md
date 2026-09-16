# DeepSeek Harness Android（DSHA）

一套开源的远程控制套件，把安卓手机连接到自托管的 **DeepSeek Harness** 实例。
包含一个安卓原生客户端、一个 macOS 桌面窗口、一个本地/远程 API 桥接服务，
以及一个用于唤起手机实时画面的 Harness 插件。

> English: [README.md](README.md)
> 详细操作手册：[docs/OPERATION_MANUAL.zh-CN.md](docs/OPERATION_MANUAL.zh-CN.md)

## 功能

- **安卓客户端**（`android/`）：横屏优先的 WebView，加载 DeepSeek Harness
  网页工作台，外层套原生控制抽屉。支持：
  - 连接任意 Harness 服务器（局域网或公网隧道）；
  - 浏览/一键安装 npm 上的 Harness 插件；
  - 添加工作区：本机文件（上传到电脑）或远端设备文件；
  - 列出已登录 Harness 的设备并控制（执行命令）；
  - 通过 VNC/noVNC 图形远控 Mac 桌面；
  - 陀螺仪视差动效（界面随手机姿态倾斜）；
  - “光粒子汇聚成 DeepSeek 鲸鱼”的开屏动画；
  - 圆角、Harness 风格的自定义弹窗（不再跟随安卓原生样式）。
- **macOS 桌面窗口**（`desktop/`）：Swift `WKWebView` 应用，自己管理 `dsh web`
  服务，显示 DeepSeek API 余额，并新增 **DSHA** 菜单项，一键唤起 `scrcpy`
  查看/操控已连接手机。
- **API 桥接**（`server/remote-api.cjs`）：轻量 Node HTTP 服务，暴露
  `/health`、`/devices`、`/plugins`、`/install`、`/upload`、`/exec`。
- **局域网中继**（`server/lan-relay.cjs`）：TCP 转发器，让手机在局域网内访问
  Harness（Harness 本身出于安全禁止绑定 `0.0.0.0`）。
- **Harness 插件**（`plugins/dsh-dsha/`）：注册 `/dsha` 命令，在 Harness 输入框
  中调用即可启动 `scrcpy`。
- **服务配置**（`launchd/`、`launchers/`）：launchd 常驻服务和命令行封装。

## 目录结构

```text
.
├── android/
│   ├── app/                         安卓应用源码
│   │   ├── AndroidManifest.xml
│   │   ├── src/com/deepseek/harness/android/
│   │   │   ├── MainActivity.java    原生抽屉 + WebView + 传感器
│   │   │   ├── VncActivity.java     全屏 noVNC 远程桌面
│   │   │   ├── ParticleSplashView.java
│   │   │   └── RemoteApi.java       HTTP 请求封装
│   │   ├── res/                     资源（自适应鲸鱼图标）
│   │   └── assets/whale.png         开屏汇聚目标位图
│   ├── build-apk.sh                 无 Gradle 构建 APK
│   └── make-icons.cjs               用 sharp 生成图标
├── desktop/
│   ├── DSHWindow.swift              macOS 窗口 + 余额 + DSHA
│   ├── start-server.sh              启动/复用 dsh web 实例
│   └── build-window.sh              swiftc 重编译 + ad-hoc 签名
├── server/
│   ├── remote-api.cjs               设备/插件/上传/执行 桥接
│   └── lan-relay.cjs                局域网 TCP 转发
├── plugins/
│   └── dsh-dsha/                    Harness 插件：/dsha -> scrcpy
├── launchd/                         macOS LaunchAgents（常驻服务）
├── launchers/
│   ├── dsh                          dsh 封装（关遥测 + 限制堆）
│   └── dsh-url                      打印当前局域网/公网地址
└── docs/
    └── OPERATION_MANUAL.zh-CN.md    详细操作手册
```

## 环境要求

### 桌面端（macOS）

- Node.js 22+（推荐 24）
- `pnpm`
- Android platform-tools（`adb`）
- `scrcpy` 4.x（DSHA 实时手机画面）
- `cloudflared`（跨网络公网隧道）
- Xcode 命令行工具（`swiftc`、`xcrun`）

### 安卓构建（仅重打包 APK 时需要）

- JDK 17
- Android SDK 命令行工具 + `build-tools;35.0.0` + `platforms;android-35`
- `sharp`（Node）

### VNC 图形远控（手机 -> Mac）

- macOS「屏幕共享」已开启（VNC 端口 5900）
- `python3` + `websockify` + `noVNC`

## 快速开始

完整步骤见 [docs/OPERATION_MANUAL.zh-CN.md](docs/OPERATION_MANUAL.zh-CN.md)。
简要流程：

```bash
# 1. 安装桌面端依赖
# 2. 构建并安装安卓 APK：
./android/build-apk.sh
adb install -r android/DeepSeek-harness-android.apk
# 3. 启动桥接、中继与隧道：
launchctl load launchd/*.plist
# 4. 把打印出来的地址填到手机端：
dsh-url
```

## 安全说明

- Harness 网页服务刻意禁止绑定 `0.0.0.0`；局域网访问应使用本项目的
  `lan-relay.cjs` 中继。
- `remote-api.cjs` 的 `/exec` 是**在电脑上执行任意 shell 命令**，务必只通过
  自己保密的隧道地址暴露。
- Cloudflare 快速隧道没有可用性保证，且重启会换域名；长期使用请改用命名
  隧道或 Tailscale。
- 为方便，VNC 密码通过 noVNC URL 传递；如果地址可能被分享，请改为手动输入。

## 许可证

MIT — 见 [LICENSE](LICENSE)。

DeepSeek 及鲸鱼 Logo 为 DeepSeek / 杭州深度求索的商标。本项目为社区非官方
集成，与 DeepSeek 无关，也未经其背书。
