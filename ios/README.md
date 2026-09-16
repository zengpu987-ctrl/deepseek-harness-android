# DSHA for iOS

SwiftUI iOS client for DeepSeek Harness. It mirrors the Android client: it wraps
the Harness web UI in `WKWebView` and adds a native control drawer for
connection, workspace, plugin marketplace, device control, graphical VNC remote
desktop, and a gyroscope parallax effect, plus a particle-whale splash screen.

## 中文说明

这是 DSHA 的 iOS（SwiftUI）版本，功能和安卓版一致：用 `WKWebView` 加载
DeepSeek Harness 网页工作台，并提供原生控制抽屉（连接、工作区、插件市场、
设备控制、VNC 图形远控、陀螺仪视差）以及鲸鱼粒子开屏动画。

## Files

```text
DSHA/
├── DSHAApp.swift        @main App entry
├── ContentView.swift    main view + native drawer + sheets
├── WebView.swift        UIViewRepresentable for WKWebView
├── RemoteAPI.swift      client for server/remote-api.cjs
├── Motion.swift         CoreMotion gyroscope parallax
├── SplashView.swift     particle -> whale splash
├── VncView.swift        full-screen noVNC remote desktop
└── Resources/whale.png  splash target bitmap
```

## Build

1. In Xcode, create a new **iOS App** project (SwiftUI, iOS 16+).
2. Add every file under `DSHA/` (except `Resources/`) to the target.
3. Add `Resources/whale.png` to the app bundle so `UIImage(named: "whale")`
   resolves. (Easiest: drag it into an `Assets.xcassets` set named `whale`.)
4. Add `NSAppTransportSecurity` with `NSAllowsArbitraryLoads = YES` to
   `Info.plist` (the Harness bridge and VNC use plain HTTP on the LAN).
5. Sign with your Apple ID and run.

No Xcode project file is committed; the source is self-contained so it can be
dropped into any SwiftUI iOS target.

## Usage

- First launch: open the top-left `☰` drawer and enter the Harness URL under
  「连接设备」 (get it from `dsh-url` on the Mac).
- 「添加工作区」 picks a workspace source (local file picker on iOS is wired
  through the Harness composer; remote opens the web picker).
- 「控制已登录设备」 lists devices from the bridge and runs commands.
- 「图形远控电脑」 prompts for the VNC password, then opens noVNC full-screen.
- 「浏览插件市场」 lists and installs `dsh-plugin` packages from npm.
- 「陀螺仪视差」 toggles the motion effect.

## Notes

- The desktop bridge (`server/remote-api.cjs`) and VNC/noVNC setup are shared
  with the Android client; see the root README and operation manual.
- The same security caveats apply: `/exec` is arbitrary shell execution, and
  Cloudflare quick-tunnel URLs change on restart.
