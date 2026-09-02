import SwiftUI

struct PreviewBackground: View {
    let settings: PreviewSettings

    @ViewBuilder
    var body: some View {
        switch settings.backgroundMode {
        case .solid:
            settings.solidColor.color

        case .checkerboard:
            CheckerboardBackground(
                tileSize: settings.checkerScale,
                mode: settings.checkerMode,
                showsCoordinates: settings.checkerShowsCoordinates
            )

        case .image:
            GeometryReader { geometry in
                Image("PreviewBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
        }
    }
}

private struct CheckerboardBackground: View {
    let tileSize: Double
    let mode: CheckerboardMode
    let showsCoordinates: Bool

    var body: some View {
        Canvas { context, size in
            let tileSize = max(CGFloat(tileSize), 1)
            let columns = Int(ceil(size.width / tileSize))
            let rows = Int(ceil(size.height / tileSize))
            let baseColor: Color = mode == .rainbowBlack ? .black : .white
            let rainbow = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
            let fillsPrimaryTiles = mode != .rainbowBlack
            let usesRainbow = mode == .rainbowWhite || mode == .rainbowBlack
            let tileShading: GraphicsContext.Shading = usesRainbow ? rainbow : .color(.black)

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(baseColor))

            for row in 0 ..< rows {
                for column in 0 ..< columns {
                    let isPrimaryTile = (row + column).isMultiple(of: 2)
                    let rect = CGRect(
                        x: CGFloat(column) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )

                    if isPrimaryTile == fillsPrimaryTiles {
                        context.fill(Path(rect), with: tileShading)
                    }

                    if showsCoordinates {
                        let labelText = "(\(column),\(row))"
                        let labelColor: Color = mode == .rainbowBlack || isPrimaryTile
                            ? .white
                            : .black
                        let characterCount = max(CGFloat(labelText.count), 1)
                        let fontSize = min(max(tileSize / (characterCount * 0.7), 3), 18)
                        let label = Text(labelText)
                            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                            .foregroundColor(labelColor)
                        context.draw(
                            label,
                            at: CGPoint(x: rect.midX, y: rect.midY),
                            anchor: .center
                        )
                    }
                }
            }
        }
    }
}
