// MARK: - Anvil mark drawn in SwiftUI (matches branding/anvil-icon.svg)

import SwiftUI

/// The Anvil anvil-and-sparks mark, drawn from the same 1024-unit coordinates
/// as the app icon so it renders without a bundled image resource.
struct AnvilMark: View {
    var accent: Color = Color(red: 0.0, green: 1.0, blue: 0.4)

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 1024
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * scale, y: y * scale)
            }
            func rounded(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat,
                         radius: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * scale, y: y * scale,
                                         width: width * scale, height: height * scale),
                     cornerRadius: radius * scale)
            }

            let iron = Color(red: 0.29, green: 0.31, blue: 0.34)
            let ironDark = Color(red: 0.16, green: 0.17, blue: 0.19)

            // Sparks
            // Each segment is (fromX, fromY, toX, toY).
            let segments: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (512, 300, 512, 200), (430, 312, 382, 236), (594, 312, 642, 236),
                (350, 352, 290, 300), (674, 352, 734, 300)
            ]
            var sparks = Path()
            for segment in segments {
                sparks.move(to: point(segment.0, segment.1))
                sparks.addLine(to: point(segment.2, segment.3))
            }
            context.stroke(sparks, with: .color(accent),
                           style: StrokeStyle(lineWidth: 22 * scale, lineCap: .round))

            // Horn
            var horn = Path()
            horn.move(to: point(236, 356))
            horn.addLine(to: point(134, 386))
            horn.addQuadCurve(to: point(134, 400), control: point(116, 392))
            horn.addLine(to: point(236, 424))
            horn.closeSubpath()
            context.fill(horn, with: .color(ironDark))

            // Face (top) with a green edge
            context.fill(rounded(212, 352, 600, 70, radius: 24), with: .color(iron))
            context.fill(rounded(212, 352, 600, 26, radius: 14), with: .color(accent.opacity(0.7)))

            // Waist and base flare
            var waist = Path()
            waist.move(to: point(300, 422))
            waist.addLine(to: point(724, 422))
            waist.addLine(to: point(690, 610))
            waist.addLine(to: point(334, 610))
            waist.closeSubpath()
            context.fill(waist, with: .color(iron))

            var flare = Path()
            flare.move(to: point(334, 610))
            flare.addLine(to: point(690, 610))
            flare.addLine(to: point(736, 700))
            flare.addLine(to: point(288, 700))
            flare.closeSubpath()
            context.fill(flare, with: .color(Color(red: 0.2, green: 0.22, blue: 0.24)))

            // Foot
            context.fill(rounded(256, 700, 512, 66, radius: 22),
                         with: .color(Color(red: 0.15, green: 0.16, blue: 0.18)))
        }
        .accessibilityHidden(true)
    }
}
