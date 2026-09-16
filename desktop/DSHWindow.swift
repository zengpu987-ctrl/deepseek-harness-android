// DSHWindow.swift — native standalone window for the DeepSeek Harness Web GUI.
//
// The app owns its window (WKWebView); no browser is involved. On launch it runs
// Resources/start-server.sh, which makes sure an app-owned `dsh web` instance is
// running and prints its authenticated URL as `URL=<url>` on stdout. That URL is
// then loaded here. Links pointing outside 127.0.0.1 open in the default browser,
// except DeepSeek pages, which stay in the app.

import Cocoa
import QuartzCore
import WebKit

private enum BootstrapError: LocalizedError {
    case scriptMissing
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .scriptMissing:
            return "应用包内缺少 Resources/start-server.sh"
        case .failed(let text):
            return text
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    private var window: NSWindow!
    private var panelWindow: NSWindow!
    private var webView: WKWebView!
    private var serverURL: URL?
    private var lastDownload: URL?

    private var glassPanel: NSVisualEffectView!
    private var balanceLabel: NSTextField!
    private var refreshButton: NSButton!
    private var rechargeButton: NSButton!
    private var returnButton: NSButton!
    private var polarisView: PolarisView!
    private var dshaProcess: Process?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenus()
        buildWindow()
        bootstrapServer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func windowWillClose(_ notification: Notification) {
        if let closing = notification.object as? NSWindow, closing === window {
            panelWindow?.close()
        }
    }

    // MARK: - Window

    private func buildWindow() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1120, height: 780), configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DeepSeek Harness"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.acceptsMouseMovedEvents = true
        window.delegate = self
        window.minSize = NSSize(width: 720, height: 520)
        window.setFrameAutosaveName("DSHMainWindow")
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let container = NSView()
        container.wantsLayer = true
        container.addSubview(webView)
        polarisView = PolarisView(frame: .zero)
        polarisView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(polarisView)
        window.contentView = container

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            polarisView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            polarisView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            polarisView.topAnchor.constraint(equalTo: container.topAnchor),
            polarisView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        buildPanelWindow()
    }

    private func buildPanelWindow() {
        let panel = NSVisualEffectView()
        panel.material = .popover
        panel.blendingMode = .behindWindow
        panel.state = .active
        panel.wantsLayer = true

        let shimmer = ShimmerView(frame: .zero)
        shimmer.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(shimmer)

        balanceLabel = NSTextField(labelWithString: "余额 --")
        balanceLabel.font = Self.uiFont(size: 13)
        balanceLabel.textColor = NSColor.black

        refreshButton = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "刷新余额")!, target: self, action: #selector(refreshBalance))
        refreshButton.bezelStyle = .rounded
        refreshButton.toolTip = "刷新余额"

        rechargeButton = NSButton(title: "充值", target: self, action: #selector(openRecharge))
        rechargeButton.bezelStyle = .rounded
        rechargeButton.font = Self.uiFont(size: 14)

        returnButton = NSButton(title: "返回 Harness", target: self, action: #selector(returnToHarness))
        returnButton.bezelStyle = .rounded
        returnButton.font = Self.uiFont(size: 14)
        returnButton.isHidden = true

        let studioLabel = NSTextField(labelWithString: "Studio Picture 图片理解")
        studioLabel.font = Self.uiFont(size: 12)
        studioLabel.textColor = NSColor.black

        let studioSwitch = NSSwitch()
        studioSwitch.controlSize = .small
        studioSwitch.target = self
        studioSwitch.action = #selector(toggleStudioPicture)
        studioSwitch.state = Self.studioPictureEnabled() ? .on : .off

        let row1 = NSStackView(views: [balanceLabel, refreshButton, rechargeButton, returnButton])
        row1.orientation = .horizontal
        row1.alignment = .centerY
        row1.spacing = 8

        let row2 = NSStackView(views: [studioLabel, studioSwitch])
        row2.orientation = .horizontal
        row2.alignment = .centerY
        row2.spacing = 8

        let stack = NSStackView(views: [row1, row2])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            shimmer.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            shimmer.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            shimmer.topAnchor.constraint(equalTo: panel.topAnchor),
            shimmer.bottomAnchor.constraint(equalTo: panel.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -9),
        ])

        stack.layoutSubtreeIfNeeded()
        let fit = stack.fittingSize
        let panelSize = NSSize(width: max(fit.width + 28, 240), height: fit.height + 18)

        glassPanel = panel

        panelWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        panelWindow.title = "DeepSeek 工具面板"
        panelWindow.contentView = panel
        panelWindow.isReleasedWhenClosed = false
        panelWindow.minSize = panelSize
        panelWindow.center()
        panelWindow.makeKeyAndOrderFront(nil)
    }

    private static func uiFont(size: CGFloat) -> NSFont {
        let cjk = NSFontDescriptor(fontAttributes: [.name: "Kaiti SC"])
        let descriptor = NSFontDescriptor(fontAttributes: [
            .name: "Times New Roman",
            .cascadeList: [cjk],
        ])
        if let font = NSFont(descriptor: descriptor, size: size) {
            return font
        }
        return NSFont(name: "Kaiti SC", size: size) ?? NSFont.systemFont(ofSize: size)
    }

    private func showPage(_ body: String) {
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><style>
        :root { color-scheme: light dark; }
        body { margin:0; height:100vh; display:flex; align-items:center; justify-content:center;
               font:15px/1.6 -apple-system, "PingFang SC", "Helvetica Neue", sans-serif;
               background:#f5f6f8; color:#1c1f23; }
        @media (prefers-color-scheme: dark) { body { background:#16181c; color:#e8eaed; } }
        .card { text-align:center; max-width:640px; padding:0 32px; }
        h1 { font-size:17px; font-weight:600; margin:18px 0 6px; }
        p { margin:6px 0; opacity:.72; }
        pre { text-align:left; white-space:pre-wrap; word-break:break-word; font-size:12px; opacity:.8;
              background:rgba(127,127,127,.12); padding:12px; border-radius:10px; max-height:280px; overflow:auto; }
        .spin { width:26px; height:26px; margin:0 auto; border:3px solid rgba(127,127,127,.25);
                border-top-color:#4d6bfe; border-radius:50%; animation:r 1s linear infinite; }
        @keyframes r { to { transform:rotate(360deg); } }
        </style></head><body><div class="card">\(body)</div></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func showLoading() {
        showPage("<div class=\"spin\"></div><h1>正在启动 DeepSeek Harness…</h1><p>首次启动需要十几秒。</p>")
    }

    private func showError(_ message: String) {
        let escaped = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        showPage("<h1>无法启动 DeepSeek Harness</h1><p>修正后可从菜单「DeepSeek Harness › 重试启动」再试。</p><pre>\(escaped)</pre>")
    }

    // MARK: - Server bootstrap

    private func bootstrapServer() {
        showLoading()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = Self.startServer()
            DispatchQueue.main.async {
                guard let self else { return }
                switch outcome {
                case .success(let url):
                    self.serverURL = url
                    self.window.title = "DeepSeek Harness"
                    self.webView.load(URLRequest(url: url))
                case .failure(let error):
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    private static func startServer() -> Result<URL, Error> {
        guard let script = Bundle.main.url(forResource: "start-server", withExtension: "sh") else {
            return .failure(BootstrapError.scriptMissing)
        }
        let home = NSHomeDirectory()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(home)/bin:\(home)/nodejs/bin:\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return .failure(error)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            let tail = output.split(separator: "\n").suffix(12).joined(separator: "\n")
            return .failure(BootstrapError.failed(tail.isEmpty ? "启动脚本退出码 \(process.terminationStatus)" : tail))
        }
        guard let line = output.split(separator: "\n").last(where: { $0.hasPrefix("URL=") }),
              let url = URL(string: String(line.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return .failure(BootstrapError.failed("启动脚本没有输出可用地址：\n\(output)"))
        }
        return .success(url)
    }

    // MARK: - Balance

    private static func readApiKey() -> String {
        if let env = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !env.isEmpty {
            return env.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".dsh/.credentials.yaml")
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return "" }
        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("DEEPSEEK_API_KEY:") else { continue }
            let value = trimmed
                .dropFirst("DEEPSEEK_API_KEY:".count)
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
            return value
        }
        return ""
    }

    @objc private func toggleStudioPicture(_ sender: NSSwitch) {
        Self.setStudioPictureEnabled(sender.state == .on)
    }

    private static func studioPictureStateFile() -> String {
        (NSHomeDirectory() as NSString).appendingPathComponent(".dsh/storages/dsh-studio-picture/state.json")
    }

    private static func studioPictureEnabled() -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: studioPictureStateFile())),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return (object["enabled"] as? Bool) ?? false
    }

    private static func setStudioPictureEnabled(_ enabled: Bool) {
        let path = studioPictureStateFile()
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let object: [String: Any] = ["enabled": enabled]
        if let data = try? JSONSerialization.data(withJSONObject: object) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    @objc private func refreshBalance() {
        let key = Self.readApiKey()
        guard !key.isEmpty else {
            balanceLabel.stringValue = "余额 未配置 API Key"
            return
        }
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/user/balance")!)
        request.timeoutInterval = 15
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let infos = json["balance_infos"] as? [[String: Any]],
                  let first = infos.first else {
                DispatchQueue.main.async { self?.balanceLabel.stringValue = "余额 查询失败" }
                return
            }
            let currency = (first["currency"] as? String) ?? "CNY"
            let total = (first["total_balance"] as? String) ?? "0"
            DispatchQueue.main.async { self?.balanceLabel.stringValue = "余额 \(currency) ¥\(total)" }
        }.resume()
    }

    // MARK: - Menu actions

    @objc private func retryBootstrap() { bootstrapServer() }

    @objc private func reloadPage() {
        if let url = serverURL {
            webView.load(URLRequest(url: url))
        } else {
            bootstrapServer()
        }
    }

    @objc private func openInBrowser() {
        if let url = serverURL { NSWorkspace.shared.open(url) }
    }

    @objc private func copyAddress() {
        guard let url = serverURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    @objc private func openRecharge() {
        if let url = URL(string: "https://platform.deepseek.com/top_up") {
            webView.load(URLRequest(url: url))
        }
    }

    @objc private func openDsha() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Users/zp/bin/scrcpy")
        process.arguments = ["--window-title", "DSHA", "--stay-awake"]
        process.environment = ProcessInfo.processInfo.environment
        do {
            try process.run()
            dshaProcess = process
        } catch {
            NSSound.beep()
        }
    }

    @objc private func returnToHarness() {
        bootstrapServer()
    }

    @objc private func showPanel() {
        if panelWindow == nil { buildPanelWindow() }
        panelWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func zoomIn() { webView.pageZoom = min(webView.pageZoom + 0.1, 3.0) }
    @objc private func zoomOut() { webView.pageZoom = max(webView.pageZoom - 0.1, 0.5) }
    @objc private func zoomReset() { webView.pageZoom = 1.0 }

    private func buildMenus() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 DeepSeek Harness", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(makeItem("重试启动", #selector(retryBootstrap), "R"))
        appMenu.addItem(makeItem("重新载入界面", #selector(reloadPage), "r"))
        appMenu.addItem(makeItem("在浏览器中打开", #selector(openInBrowser), "O"))
        appMenu.addItem(makeItem("复制当前地址", #selector(copyAddress), "l"))
        appMenu.addItem(.separator())
        appMenu.addItem(makeItem("DeepSeek 余额 / 充值", #selector(openRecharge), "b"))
        appMenu.addItem(makeItem("DSHA（远控安卓手机）", #selector(openDsha), "d"))
        appMenu.addItem(makeItem("显示工具面板", #selector(showPanel), ""))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 DeepSeek Harness", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出 DeepSeek Harness", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "显示")
        viewMenu.addItem(makeItem("放大", #selector(zoomIn), "+"))
        viewMenu.addItem(makeItem("缩小", #selector(zoomOut), "-"))
        viewMenu.addItem(makeItem("实际大小", #selector(zoomReset), "0"))
        viewItem.submenu = viewMenu

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    private func makeItem(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Navigation

    private static func isLocal(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    private static func isDeepSeek(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        return host == "deepseek.com" || host.hasSuffix(".deepseek.com")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let scheme = (url.scheme ?? "").lowercased()
        if scheme == "http" || scheme == "https" {
            if Self.isDeepSeek(url) {
                decisionHandler(.allow)
                return
            }
            if !Self.isLocal(url) || navigationAction.targetFrame == nil {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let current = webView.url
        let local = current == nil ? true : Self.isLocal(current!)
        returnButton.isHidden = local
        rechargeButton.isHidden = !local
        if local {
            refreshBalance()
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    // MARK: - Downloads

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let directory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        let safeName = suggestedFilename.isEmpty ? "download" : suggestedFilename
        var target = directory.appendingPathComponent(safeName)
        let base = target.deletingPathExtension().lastPathComponent
        let ext = target.pathExtension
        var counter = 1
        while FileManager.default.fileExists(atPath: target.path) {
            let name = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            target = directory.appendingPathComponent(name)
            counter += 1
        }
        lastDownload = target
        completionHandler(target)
    }

    func downloadDidFinish(_ download: WKDownload) {
        if let url = lastDownload { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        lastDownload = nil
    }
}

/// A light-blue animated light sweep used as the liquid-glass panel background.
final class ShimmerView: NSView {
    private let gradient = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(gradient)
        gradient.colors = [
            NSColor(calibratedRed: 0.58, green: 0.78, blue: 1.0, alpha: 0.0).cgColor,
            NSColor(calibratedRed: 0.78, green: 0.90, blue: 1.0, alpha: 0.55).cgColor,
            NSColor(calibratedRed: 0.58, green: 0.78, blue: 1.0, alpha: 0.0).cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.locations = [0.0, 0.25, 0.5]

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0.0, 0.15, 0.3]
        animation.toValue = [0.7, 0.85, 1.0]
        animation.duration = 2.6
        animation.autoreverses = true
        animation.repeatCount = .infinity
        gradient.add(animation, forKey: "shimmer")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        gradient.frame = bounds
    }
}

/// Full-window transparent liquid-glass veil: a faint light-blue tint plus an
/// animated diagonal light sweep. Mouse events pass through to the webview below.
final class PolarisView: NSView {
    private var cursor: CGPoint?
    private var trail: [CGPoint] = []
    private var phase: CGFloat = 0
    private var animationTimer: Timer?
    private let golden = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.28, alpha: 1.0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        cursor = convert(event.locationInWindow, from: nil)
    }

    override func mouseExited(with event: NSEvent) {
        cursor = nil
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func startAnimating() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.06
            if let c = self.cursor {
                self.trail.append(c)
                if self.trail.count > 72 { self.trail.removeFirst() }
            } else if !self.trail.isEmpty {
                self.trail.removeFirst()
            }
            self.needsDisplay = true
        }
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let n = trail.count
        guard n > 1 else {
            if let c = cursor ?? trail.first {
                drawStar(at: c, radius: 6.5, alpha: 1.0, leading: true)
            }
            return
        }

        // Sample seven stars along the recent movement path: the leading star
        // sits at the cursor, the other six trail behind it along the trajectory.
        let spacing = 5
        var stars: [CGPoint] = []
        for i in 0..<7 {
            let idx = n - 1 - i * spacing
            if idx >= 0 { stars.append(trail[idx]) }
        }

        let line = NSBezierPath()
        line.lineWidth = 1.1
        for i in 0..<(stars.count - 1) {
            line.move(to: stars[i])
            line.line(to: stars[i + 1])
        }
        golden.withAlphaComponent(0.5).setStroke()
        line.stroke()

        for (i, point) in stars.enumerated() {
            let t = CGFloat(i) / 6.0
            let alpha = 1.0 - 0.85 * t
            let radius = 6.2 - 4.6 * t
            drawStar(at: point, radius: max(radius, 1.2), alpha: max(alpha, 0.12), leading: i == 0)
        }
    }

    private func drawStar(at point: CGPoint, radius: CGFloat, alpha: CGFloat, leading: Bool) {
        if leading, let ctx = NSGraphicsContext.current?.cgContext {
            let glowRadius = radius * 4 + 6 * sin(phase)
            let glowColors = [
                NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.35, alpha: 0.35).cgColor,
                NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.22, alpha: 0.10).cgColor,
                NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.22, alpha: 0.0).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 0.5, 1]) {
                ctx.drawRadialGradient(gradient, startCenter: point, startRadius: 0, endCenter: point, endRadius: glowRadius, options: [])
            }
        }

        golden.withAlphaComponent(alpha * 0.85).setFill()
        NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)).fill()

        NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.78, alpha: alpha).setFill()
        NSBezierPath(ovalIn: NSRect(x: point.x - radius * 0.45, y: point.y - radius * 0.45, width: radius * 0.9, height: radius * 0.9)).fill()

        let rays = NSBezierPath()
        rays.lineWidth = 1.1
        golden.withAlphaComponent(alpha * 0.9).setStroke()
        for k in 0..<4 {
            let angle = phase * 0.9 + CGFloat(k) * .pi / 2
            rays.move(to: CGPoint(x: point.x - cos(angle) * radius * 0.5, y: point.y - sin(angle) * radius * 0.5))
            rays.line(to: CGPoint(x: point.x + cos(angle) * radius * 2.2, y: point.y + sin(angle) * radius * 2.2))
        }
        rays.stroke()
    }
}

@main
struct DSHMain {
    // NSApplication.delegate is weak, so the delegate needs static storage.
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
