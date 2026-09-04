import SwiftUI

struct ShaderPreviewView: View {
    private static let profileSampleCount = 256

    let settings: ShaderSettings

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height) * 0.58

            Circle()
                .fill(.white)
                .frame(width: side, height: side)
                .colorEffect(shader(size: side))
                .shadow(color: .black.opacity(0.28), radius: side * 0.08, y: side * 0.04)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Lambert-shaded radial profile preview")
        }
    }

    private func shader(size: CGFloat) -> Shader {
        let stops = GradientRules.sanitized(settings.diffuseGradientStops)
        let heightTable = settings.profileCurve.lookupTable(
            in: 0 ... 1,
            sampleCount: Self.profileSampleCount
        )
        let derivativeTable = settings.profileCurve.derivativeLookupTable(
            in: 0 ... 1,
            sampleCount: Self.profileSampleCount
        )

        return ShaderLibrary.lambertRadialProfile(
            .float2(size, size),
            .float(radians(settings.gradientDirectionDegrees)),
            .floatArray(stops.map { Float($0.location) }),
            .colorArray(stops.map(\.color.color)),
            .float(radians(settings.lightDirectionDegrees)),
            .float(settings.lightDistance),
            .float(settings.lightDepth),
            .float(settings.lightBrightness),
            .color(settings.lightColor.color),
            .float(settings.ambientStrength),
            .color(settings.ambientColor.color),
            .floatArray(finiteSamples(heightTable.samples)),
            .floatArray(finiteSamples(derivativeTable.samples))
        )
    }

    private func radians(_ degrees: Double) -> Float {
        Float(AngleRules.normalizedDegrees(degrees) * .pi / 180)
    }

    private func finiteSamples(_ samples: [Float]) -> [Float] {
        samples.map { sample in
            guard sample.isFinite else { return 0 }
            return min(max(sample, -10000), 10000)
        }
    }
}
