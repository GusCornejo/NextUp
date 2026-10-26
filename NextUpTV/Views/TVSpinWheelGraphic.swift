import SwiftUI
import BacklogCore

/// Large pie-slice wheel for the living-room display; rotation applied by parent.
struct TVSpinWheelGraphic: View {
    let slices: [BacklogItem]
    let weights: [Double]
    let highlightedID: UUID?

    private let palette: [Color] = [
        Color(red: 0.745, green: 0.914, blue: 0.910),
        Color(red: 0.384, green: 0.714, blue: 0.796),
        Color(red: 0.106, green: 0.286, blue: 0.396),
        Color(red: 0.792, green: 0.914, blue: 1.000),
        Color(red: 0.373, green: 0.659, blue: 0.827),
        Color(red: 0.906, green: 0.941, blue: 0.945),
    ]

    var body: some View {
        Canvas { context, size in
            let total = max(weights.reduce(0, +), 0.0001)
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            var start = -Double.pi / 2

            for (index, item) in slices.enumerated() {
                let weight = index < weights.count ? weights[index] : 1
                let sweep = (weight / total) * 2 * Double.pi
                let end = start + sweep

                var path = Path()
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .radians(start),
                    endAngle: .radians(end),
                    clockwise: false
                )
                path.closeSubpath()

                let base = palette[index % palette.count]
                let fill = item.id == highlightedID ? base : base.opacity(0.9)
                context.fill(path, with: .color(fill))
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.4)),
                    lineWidth: 2
                )

                let mid = start + sweep / 2
                let labelRadius = radius * 0.62
                let labelPoint = CGPoint(
                    x: center.x + CGFloat(cos(mid)) * labelRadius,
                    y: center.y + CGFloat(sin(mid)) * labelRadius
                )
                context.draw(
                    Text(truncatedTitle(item.title))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white),
                    at: labelPoint,
                    anchor: .center
                )

                start = end
            }

            let hubSize = radius * 0.14
            let hub = Path(
                ellipseIn: CGRect(
                    x: center.x - hubSize,
                    y: center.y - hubSize,
                    width: hubSize * 2,
                    height: hubSize * 2
                )
            )
            context.fill(hub, with: .color(.white.opacity(0.92)))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spin wheel with \(slices.count) items")
    }

    private func truncatedTitle(_ title: String) -> String {
        if title.count <= 14 { return title }
        return String(title.prefix(13)) + "…"
    }
}

struct TVWheelPointer: View {
    var body: some View {
        Image(systemName: "arrowtriangle.down.fill")
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(Color(red: 0.86, green: 0.45, blue: 0.28))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            .accessibilityHidden(true)
    }
}
