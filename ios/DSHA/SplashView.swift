import SwiftUI
import UIKit

/// Light particles converge from the screen edges into the DeepSeek whale mark,
/// then the view is removed by the parent.
struct SplashView: View {
    var onFinished: () -> Void

    private let particles: [Particle]
    @State private var start = Date()

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        self.particles = SplashView.makeParticles()
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(red: 0.02, green: 0.03, blue: 0.07))
                )
                for p in particles {
                    let local = min(max((t - p.delay) / p.duration, 0), 1)
                    let eased = Self.easeOutCubic(local)
                    let x = (p.sx + (p.ex - p.sx) * eased) * size.width
                    let y = (p.sy + (p.ey - p.sy) * eased) * size.height
                    let alpha = 0.55 + 0.45 * eased
                    let rect = CGRect(
                        x: x - p.radius,
                        y: y - p.radius,
                        width: p.radius * 2,
                        height: p.radius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(alpha)))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.7) { onFinished() }
        }
    }

    private static func makeParticles() -> [Particle] {
        var targets: [CGPoint] = []
        if let image = UIImage(named: "whale"), let cg = image.cgImage {
            let width = cg.width
            let height = cg.height
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            if let ctx = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
                for y in stride(from: 0, to: height, by: 3) {
                    for x in stride(from: 0, to: width, by: 3) {
                        let index = (y * width + x) * 4
                        if pixels[index + 3] > 96 {
                            targets.append(CGPoint(x: CGFloat(x) / CGFloat(width),
                                                   y: CGFloat(y) / CGFloat(height)))
                        }
                    }
                }
            }
        }
        if targets.isEmpty {
            targets = (0..<140).map {
                CGPoint(x: 0.5 + 0.30 * cos(Double($0) / 19),
                        y: 0.5 + 0.20 * sin(Double($0) / 9))
            }
        }

        let warm = Color(red: 0.59, green: 0.73, blue: 1.0)
        let cool = Color(red: 0.30, green: 0.42, blue: 1.0)
        var particles: [Particle] = []
        for _ in 0..<460 {
            let target = targets.randomElement()!
            let edge = Int.random(in: 0..<4)
            let sx: CGFloat
            let sy: CGFloat
            switch edge {
            case 0: sx = .random(in: -0.05...1.05); sy = -0.03
            case 1: sx = .random(in: -0.05...1.05); sy = 1.03
            case 2: sx = -0.03; sy = .random(in: -0.05...1.05)
            default: sx = 1.03; sy = .random(in: -0.05...1.05)
            }
            particles.append(Particle(
                sx: sx, sy: sy,
                ex: target.x, ey: target.y,
                delay: .random(in: 0...1.1),
                duration: .random(in: 2.2...3.6),
                radius: .random(in: 1.4...3.6),
                color: Bool.random() ? warm : cool
            ))
        }
        return particles
    }

    private static func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let u = 1 - t
        return 1 - u * u * u
    }
}

private struct Particle {
    let sx: CGFloat
    let sy: CGFloat
    let ex: CGFloat
    let ey: CGFloat
    let delay: CGFloat
    let duration: CGFloat
    let radius: CGFloat
    let color: Color
}
