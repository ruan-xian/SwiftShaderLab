import SwiftUI

/// Replace this view with the shader or renderer under development.
/// Keep the `ShaderSettings` input so the surrounding lab remains reusable.
/// Remove the template's existing settings and inspector tabs, then replace them
/// with controls for your shader, reusing the predefined controls where possible.
struct ShaderPreviewView: View {
    let settings: ShaderSettings

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height) * 0.58
                let phase = context.date.timeIntervalSinceReferenceDate * settings.speed

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                stops: settings.gradientStops.map {
                                    Gradient.Stop(
                                        color: $0.color.color,
                                        location: CGFloat($0.location)
                                    )
                                },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Ellipse()
                        .fill(.white.opacity(0.46 * settings.intensity))
                        .frame(width: side * 0.52, height: side * 0.18)
                        .blur(radius: side * 0.05)
                        .offset(x: -side * 0.10, y: -side * 0.21)
                        .rotationEffect(.radians(phase * 0.25))

                    Circle()
                        .stroke(.white.opacity(0.42), lineWidth: max(side * 0.012, 1))
                        .blur(radius: side * 0.006)

                    BezierCurveGraphOverlay(examples: settings.bezierCurves)
                        .padding(side * 0.08)
                        .clipShape(Circle())
                }
                .frame(width: side, height: side)
                .scaleEffect(settings.scale.clamped(to: 0.2 ... 1.6))
                // SwiftUI uses screen coordinates, so negate the mathematical CCW angle.
                .rotationEffect(.degrees(-settings.angleDegrees))
                .rotationEffect(.radians(sin(phase) * 0.08))
                .shadow(color: .black.opacity(0.28), radius: side * 0.08, y: side * 0.04)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Shader preview placeholder")
            }
        }
    }
}

private struct BezierCurveGraphOverlay: View {
    let examples: BezierCurveExamples

    var body: some View {
        Canvas { context, size in
            draw(
                examples.easing,
                color: BezierExamplePalette.easing,
                context: &context,
                size: size
            )
            draw(
                examples.transfer,
                color: BezierExamplePalette.transfer,
                context: &context,
                size: size
            )
            draw(
                examples.partialDomain,
                color: BezierExamplePalette.partialDomain,
                context: &context,
                size: size
            )
        }
        .accessibilityHidden(true)
    }

    private func draw(
        _ curve: BezierCurve,
        color: Color,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let table = curve.lookupTable(in: 0 ... 1, sampleCount: 256)
        guard table.samples.count > 1 else { return }

        var path = Path()
        for index in table.samples.indices {
            let progress = CGFloat(index) / CGFloat(table.samples.count - 1)
            let point = CGPoint(
                x: progress * size.width,
                y: size.height - CGFloat(table.samples[index]) * size.height
            )
            if index == table.samples.startIndex {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        context.stroke(path, with: .color(.black.opacity(0.45)), lineWidth: 5)
        context.stroke(path, with: .color(color), lineWidth: 2.5)
    }
}
