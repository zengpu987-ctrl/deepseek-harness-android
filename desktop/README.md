# DeepSeek Harness（独立窗口版）

双击本应用会打开一个**属于它自己的窗口**（macOS 原生 WKWebView），在里面显示 DSH 的 Web GUI，
不再打开、也不占用任何浏览器。

## 组成

```
DeepSeek Harness.app/Contents/
├── MacOS/DeepSeekHarness        窗口程序（Swift + WKWebView，已 ad-hoc 签名）
└── Resources/
    ├── DSHWindow.swift          窗口程序源码
    ├── build-window.sh          重新编译窗口程序
    ├── start-server.sh          确保有可用的 dsh 实例，并输出认证地址
    ├── dsh-app                  命令行控制工具
    ├── AppIcon.icns             图标
    └── README.md                本文件
```

启动流程：窗口程序调用 `start-server.sh` → 脚本复用或启动 `dsh web`，把带 token 的地址
以 `URL=…` 打印到 stdout → 窗口加载该地址；启动期间窗口显示加载页，失败时显示错误信息。

## 为什么必须带 token

DSH 的 Web GUI 只接受携带启动 token 的地址（该地址会写入一个 HttpOnly 会话 cookie）。
直接访问 `http://127.0.0.1:端口/` 而没有 cookie 时，服务器返回
`401 dsh web authentication required`。

token 是每个 `dsh web` 进程随机生成的，只出现在该进程的输出里。**在终端里手动启动的 DSH
实例，其 token 无法被本应用取得**，所以本应用不会加载一个无法认证的地址，而是在下一个空闲
端口启动自己的实例。等那个终端实例退出、3080 空出来后，本应用下次就会用 3080。

## 窗口与菜单

| 菜单项 | 快捷键 | 作用 |
| --- | --- | --- |
| 重试启动 | ⇧⌘R | 重新执行启动流程（启动失败后用） |
| 重新载入界面 | ⌘R | 重新加载当前界面 |
| 在浏览器中打开 | ⇧⌘O | 需要时把同一地址交给默认浏览器 |
| 复制当前地址 | ⌘L | 复制带 token 的地址 |
| 放大 / 缩小 / 实际大小 | ⌘+ / ⌘- / ⌘0 | 页面缩放 |
| 退出 | ⌘Q | 关闭窗口并退出应用（后台的 dsh 服务继续运行） |

指向 `127.0.0.1` 以外的链接、以及 `target=_blank` 的新窗口链接，会交给默认浏览器打开；
下载的文件保存到 `~/Downloads` 并在访达中显示。

## 命令行控制

```sh
"/Applications/DeepSeek Harness.app/Contents/Resources/dsh-app" status   # 端口 / pid / 认证地址
"/Applications/DeepSeek Harness.app/Contents/Resources/dsh-app" stop     # 停止 dsh 服务
"/Applications/DeepSeek Harness.app/Contents/Resources/dsh-app" restart
"/Applications/DeepSeek Harness.app/Contents/Resources/dsh-app" open     # 在浏览器中打开
"/Applications/DeepSeek Harness.app/Contents/Resources/dsh-app" logs     # 跟踪服务器日志
```

## 配置

编辑 `~/Library/Application Support/DeepSeek Harness/config.env`（没有就新建）：

```sh
DSH_WEB_PORT=8080                 # 固定首选端口；设置后不再自动顺延
DSH_BIN=/Users/you/nodejs/bin/dsh # 指定 dsh 可执行文件
```

## 日志与状态

| 内容 | 位置 |
| --- | --- |
| 服务器日志 | `~/Library/Logs/DeepSeek Harness/dsh-web.log` |
| 启动器日志 | `~/Library/Logs/DeepSeek Harness/launcher.log` |
| 当前实例（端口 / pid / 认证地址） | `~/Library/Application Support/DeepSeek Harness/instance.env` |

## 重新编译窗口程序

改动 `DSHWindow.swift` 后：

```sh
"/Applications/DeepSeek Harness.app/Contents/Resources/build-window.sh"
```

脚本用 `xcrun swiftc` 编译并用 `codesign --sign -` 重新做 ad-hoc 签名，然后重新注册应用即可。
