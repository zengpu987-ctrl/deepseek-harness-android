import CoreMotion
import WebKit

/// Reads device orientation and pushes a parallax tilt into the harness WebView.
final class MotionController: ObservableObject {
    @Published var enabled: Bool =
        UserDefaults.standard.object(forKey: "motion") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "motion")
            if !enabled { reset() }
        }
    }

    private let motionManager = CMMotionManager()
    private weak var webView: WKWebView?
    private var lastPush = Date.distantPast

    func attach(to webView: WKWebView) {
        self.webView = webView
        injectMotionScript(webView)
        start()
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, self.enabled, let motion else { return }
            let now = Date()
            guard now.timeIntervalSince(self.lastPush) > 0.05 else { return }
            self.lastPush = now
            let pitch = motion.attitude.pitch * 180 / .pi
            let roll = motion.attitude.roll * 180 / .pi
            self.webView?.evaluateJavaScript(
                "window.__dshMotion && window.__dshMotion(\(pitch),\(roll))",
                completionHandler: nil
            )
        }
    }

    func stop() { motionManager.stopDeviceMotionUpdates() }

    func reset() {
        webView?.evaluateJavaScript(
            "window.__dshMotionReset && window.__dshMotionReset()",
            completionHandler: nil
        )
    }

    private func injectMotionScript(_ webView: WKWebView) {
        let script = """
        (function(){if(window.__dshMotionInstalled)return;window.__dshMotionInstalled=true;
        var tx=0,ty=0,cx=0,cy=0;
        window.__dshMotion=function(pitch,roll){cx=Math.max(-9,Math.min(9,pitch*1.15));cy=Math.max(-9,Math.min(9,roll*1.15));};
        window.__dshMotionReset=function(){cx=0;cy=0;};
        function loop(){tx+=(cx-tx)*0.12;ty+=(cy-ty)*0.12;var b=document.body;
        if(b){b.style.transform='perspective(850px) rotateX('+tx.toFixed(3)+'deg) rotateY('+ty.toFixed(3)+'deg) translateX('+(ty*6).toFixed(1)+'px) translateY('+(tx*6).toFixed(1)+'px)';b.style.willChange='transform';}
        requestAnimationFrame(loop);}requestAnimationFrame(loop);})();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}
