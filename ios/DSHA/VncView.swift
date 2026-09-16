import SwiftUI

/// Full-screen noVNC remote desktop.
struct VncView: View {
    let url: URL

    var body: some View {
        WebView(url: url)
            .ignoresSafeArea()
    }
}
