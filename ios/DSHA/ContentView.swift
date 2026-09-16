import SwiftUI
import WebKit

struct ContentView: View {
    @AppStorage("harnessURL") private var harnessURL = ""
    @AppStorage("apiURL") private var apiURL =
        "https://found-final-isolation-palm.trycloudflare.com"
    @AppStorage("vncBase") private var vncBase =
        "https://complimentary-distances-refresh-surprised.trycloudflare.com/vnc.html?autoconnect=true&reconnect=true&path=websockify"
    @AppStorage("vncPassword") private var vncPassword = ""

    @StateObject private var motion = MotionController()
    @State private var showDrawer = false
    @State private var showSplash = true
    @State private var showVNC = false
    @State private var vncURL: URL?
    @State private var webView: WKWebView?

    var body: some View {
        ZStack(alignment: .topLeading) {
            WebView(url: URL(string: harnessURL)) { created in
                webView = created
                motion.attach(to: created)
            }
            .ignoresSafeArea()

            if showSplash {
                SplashView { withAnimation { showSplash = false } }
                    .transition(.opacity)
                    .zIndex(10)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showDrawer.toggle() }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.14))
                    )
            }
            .padding(8)
            .zIndex(9)

            if showDrawer {
                DrawerView(
                    harnessURL: $harnessURL,
                    apiURL: $apiURL,
                    vncBase: $vncBase,
                    vncPassword: $vncPassword,
                    motionEnabled: $motion.enabled,
                    webView: webView,
                    onClose: { withAnimation { showDrawer = false } },
                    onConnect: { url in webView?.load(URLRequest(url: URL(string: url)!)) },
                    onOpenVNC: { url in
                        vncURL = url
                        showVNC = true
                    }
                )
                .transition(.move(edge: .leading))
                .zIndex(8)
            }
        }
        .onDisappear { motion.stop() }
        .sheet(isPresented: $showVNC) {
            if let vncURL {
                VncView(url: vncURL)
            }
        }
    }
}

private struct DrawerView: View {
    @Binding var harnessURL: String
    @Binding var apiURL: String
    @Binding var vncBase: String
    @Binding var vncPassword: String
    @Binding var motionEnabled: Bool
    weak var webView: WKWebView?
    var onClose: () -> Void
    var onConnect: (String) -> Void
    var onOpenVNC: (URL) -> Void

    @State private var urlField = ""
    @State private var showWorkspace = false
    @State private var showDevices = false
    @State private var showMarket = false
    @State private var showVncPrompt = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("DeepSeek Harness iOS")
                        .font(.headline)
                        .foregroundColor(.white)

                    section("连接设备") {
                        TextField("http://ip:port/?token=...", text: $urlField)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Button("连接") {
                            let url = normalized(urlField)
                            harnessURL = url
                            onConnect(url)
                            onClose()
                        }
                        .buttonStyle(FilledButtonStyle())
                    }

                    section("工作区") {
                        Button("添加工作区") { showWorkspace = true }
                            .buttonStyle(FilledButtonStyle())
                    }

                    section("远端控制") {
                        Button("控制已登录设备") { showDevices = true }
                            .buttonStyle(FilledButtonStyle())
                        Button("图形远控电脑") { showVncPrompt = true }
                            .buttonStyle(FilledButtonStyle())
                    }

                    section("远程服务 / 插件市场") {
                        TextField("https://...trycloudflare.com", text: $apiURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Button("浏览插件市场") { showMarket = true }
                            .buttonStyle(FilledButtonStyle())
                    }

                    section("动效") {
                        Toggle("陀螺仪视差", isOn: $motionEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.3, green: 0.42, blue: 1)))
                    }

                    Button("关闭面板") { onClose() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(16)
            }
            .frame(width: 320)
            .background(Color(red: 0.055, green: 0.067, blue: 0.094))

            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { urlField = harnessURL }
        .confirmationDialog("选择工作区来源", isPresented: $showWorkspace, titleVisibility: .visible) {
            Button("安卓手机内部文件") { pickLocalWorkspace() }
            Button("远端设备文件") { openRemoteWorkspace() }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showDevices) { DeviceListSheet(apiURL: apiURL) }
        .sheet(isPresented: $showMarket) { MarketSheet(apiURL: apiURL) }
        .sheet(isPresented: $showVncPrompt) {
            VncPasswordSheet(base: vncBase, password: $vncPassword) { url in onOpenVNC(url) }
        }
    }

    private func normalized(_ url: String) -> String {
        if url.hasPrefix("http://") || url.hasPrefix("https://") { return url }
        return "http://" + url
    }

    private func pickLocalWorkspace() {
        // Placeholder: file upload is wired through the harness composer in this iOS build.
    }

    private func openRemoteWorkspace() {
        webView?.evaluateJavaScript(
            "(function(){var els=document.querySelectorAll('button');for(var i=0;i<els.length;i++){var t=(els[i].innerText||'').trim();if(t.indexOf('Choose workspace')>=0||t.indexOf('选择工作区')>=0||t.indexOf('工作区')>=0){els[i].click();return;}}})();",
            completionHandler: nil
        )
    }
}

private struct DeviceListSheet: View {
    let apiURL: String
    @State private var devices: [Device] = []
    @State private var command = ""
    @State private var output = ""

    var body: some View {
        NavigationStack {
            List(devices) { device in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(device.name)  (\(device.host))").font(.headline)
                    TextField("要执行的命令", text: $command)
                        .textFieldStyle(.roundedBorder)
                    Button("执行") {
                        Task {
                            let result = try? await RemoteAPI(baseURL: apiURL).exec(command)
                            output = (result?.stdout ?? "") + (result?.stderr ?? "")
                        }
                    }
                    if !output.isEmpty {
                        Text(output).font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .navigationTitle("选择要控制的设备")
            .task {
                devices = (try? await RemoteAPI(baseURL: apiURL).devices()) ?? []
            }
        }
    }
}

private struct MarketSheet: View {
    let apiURL: String
    @State private var plugins: [Plugin] = []

    var body: some View {
        NavigationStack {
            List(plugins) { plugin in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(plugin.name)  \(plugin.version)").font(.headline)
                    if let description = plugin.description {
                        Text(description).font(.caption).foregroundColor(.secondary)
                    }
                    Button("安装 \(plugin.name)") {
                        Task { try? await RemoteAPI(baseURL: apiURL).install(plugin.name) }
                    }
                }
            }
            .navigationTitle("插件市场")
            .task {
                plugins = (try? await RemoteAPI(baseURL: apiURL).plugins()) ?? []
            }
        }
    }
}

private struct VncPasswordSheet: View {
    let base: String
    @Binding var password: String
    var onOpen: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("远控电脑").font(.headline)
            SecureField("输入 VNC 密码", text: $password)
                .textFieldStyle(.roundedBorder)
            Button("连接并操控电脑") {
                if let url = URL(string: base + "&password=" + (password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) {
                    onOpen(url)
                    dismiss()
                }
            }
            .buttonStyle(FilledButtonStyle())
        }
        .padding()
        .presentationDetents([.height(220)])
    }
}

private struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.30, green: 0.42, blue: 1.0).opacity(configuration.isPressed ? 0.75 : 1))
            )
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.12))
            )
    }
}

@ViewBuilder
private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.system(size: 12))
            .foregroundColor(Color.white.opacity(0.6))
        content()
    }
}
