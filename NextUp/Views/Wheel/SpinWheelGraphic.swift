import SwiftUI
import BacklogCore

/// Pie-slice wheel drawn with a Canvas; rotation is applied by the parent.
struct SpinWheelGraphic: View {
    let slices: [BacklogItem]
    let weights: [Double]
    let highlightedID: UUID?

    private let palette: [Color] = [
        Color(red: 0.18, green: 0.42, blue: 0.55),
        Color(red: 0.86, green: 0.45, blue: 0.28),
        Color(red: 0.25, green: 0.55, blue: 0.40),
        Color(red: 0.55, green: 0.35, blue: 0.55),
        Color(red: 0.75, green: 0.55, blue: 0.20),
        Color(red: 0.35, green: 0.50, blue: 0.70),
        Color(red: 0.65, green: 0.30, blue: 0.35),
        Color(red: 0.30, green: 0.45, blue: 0.35),
        Color(red: 0.50, green: 0.40, blue: 0.25),
        Color(red: 0.40, green: 0.35, blue: 0.60),
        Color(red: 0.20, green: 0.50, blue: 0.55),
        Color(red: 0.70, green: 0.40, blue: 0.45),
    ]

    var body: some View {
        Canvas { context, size in
            let total = max(weights.reduce(0, +), 0.0001)
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // Start at top (−π/2) and go clockwise.
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
                let fill = item.id == highlightedID
                    ? base.opacity(1)
                    : base.opacity(0.92)
                context.fill(path, with: .color(fill))
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.35)),
                    lineWidth: 1
                )

                let mid = start + sweep / 2
                let labelRadius = radius * 0.62
                let labelPoint = CGPoint(
                    x: center.x + CGFloat(cos(mid)) * labelRadius,
                    y: center.y + CGFloat(sin(mid)) * labelRadius
                )
                let label = truncatedTitle(item.title)
                context.draw(
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white),
                    at: labelPoint,
                    anchor: .center
                )

                start = end
            }

            // Hub
            let hub = Path(
                ellipseIn: CGRect(
                    x: center.x - radius * 0.12,
                    y: center.y - radius * 0.12,
                    width: radius * 0.24,
                    height: radius * 0.24
                )
            )
            context.fill(hub, with: .color(.white.opacity(0.9)))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spin wheel with \(slices.count) items")
    }

    private func truncatedTitle(_ title: String) -> String {
        if title.count <= 10 { return title }
        return String(title.prefix(9)) + "…"
    }
}

/// Pointer sitting above the wheel (marks the winning slice).
struct WheelPointer: View {
    var body: some View {
        Image(systemName: "arrowtriangle.down.fill")
            .font(.title)
            .foregroundStyle(Color(red: 0.86, green: 0.45, blue: 0.28))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .accessibilityHidden(true)
    }
}
