import SwiftUI
import UIKit

/// A dial and degree-entry control using the mathematical angle convention:
/// 0° points along the positive x-axis (right), and positive angles turn counterclockwise.
struct AngleControl: View {
    private static let dialSize: CGFloat = 86

    let title: String
    @Binding var angleDegrees: Double
    var defaultAngleDegrees: Double?

    @State private var angleText: String
    @FocusState private var isTextFieldFocused: Bool

    init(
        title: String,
        angleDegrees: Binding<Double>,
        defaultAngleDegrees: Double? = nil
    ) {
        self.title = title
        _angleDegrees = angleDegrees
        self.defaultAngleDegrees = defaultAngleDegrees
        _angleText = State(initialValue: Self.formatted(angleDegrees.wrappedValue))
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)

            Spacer()

            dial

            HStack(spacing: 4) {
                TextField("Degrees", text: $angleText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($isTextFieldFocused)
                    .frame(width: 72)
                    .onSubmit(commitText)
                    .accessibilityLabel("\(title) degrees")

                Text("°")
                    .foregroundStyle(.secondary)
            }

            if let defaultAngleDegrees {
                Button("Reset") {
                    setAngle(defaultAngleDegrees)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(
                    abs(
                        AngleRules.normalizedDegrees(angleDegrees)
                            - AngleRules.normalizedDegrees(defaultAngleDegrees)
                    ) < 0.000_001
                )
            }
        }
        .font(.caption)
        .onAppear {
            setAngle(angleDegrees)
        }
        .onChange(of: angleDegrees) { _, newValue in
            guard !isTextFieldFocused else { return }
            angleText = Self.formatted(newValue)
        }
        .onChange(of: isTextFieldFocused) { _, isFocused in
            if !isFocused {
                commitText()
            }
        }
    }

    private var dial: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 10
            let endpoint = handEndpoint(center: center, radius: radius)

            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                Circle()
                    .stroke(Color.secondary.opacity(0.45), lineWidth: 1)

                ForEach(0 ..< 8) { index in
                    Capsule()
                        .fill(Color.secondary.opacity(index.isMultiple(of: 2) ? 0.6 : 0.3))
                        .frame(width: 1, height: index.isMultiple(of: 2) ? 7 : 4)
                        .offset(y: -geometry.size.height / 2 + 7)
                        .rotationEffect(.degrees(Double(index) * 45))
                }

                Path { path in
                    path.move(to: center)
                    path.addLine(to: endpoint)
                }
                .stroke(.tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                Circle()
                    .fill(.tint)
                    .frame(width: 12, height: 12)
                    .position(endpoint)

                Circle()
                    .fill(.tint)
                    .frame(width: 6, height: 6)

                Circle()
                    .fill(.clear)
                    .contentShape(Circle())
                    .gesture(dragGesture(center: center))
            }
        }
        .frame(width: Self.dialSize, height: Self.dialSize)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(
            Text(angleDegrees, format: .number.precision(.fractionLength(0 ... 2)))
        )
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? 1.0 : -1.0
            setAngle(angleDegrees + delta)
        }
    }

    private func handEndpoint(center: CGPoint, radius: CGFloat) -> CGPoint {
        let radians = AngleRules.normalizedDegrees(angleDegrees) * .pi / 180
        return CGPoint(
            x: center.x + CGFloat(cos(radians)) * radius,
            y: center.y - CGFloat(sin(radians)) * radius
        )
    }

    private func dragGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let deltaX = value.location.x - center.x
                let deltaY = center.y - value.location.y
                let degrees = atan2(deltaY, deltaX) * 180 / .pi
                setAngle(Double(degrees))
            }
    }

    private func commitText() {
        guard let degrees = Double(angleText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            angleText = Self.formatted(angleDegrees)
            return
        }
        setAngle(degrees)
    }

    private func setAngle(_ degrees: Double) {
        angleDegrees = AngleRules.normalizedDegrees(degrees)
        angleText = Self.formatted(angleDegrees)
    }

    private static func formatted(_ degrees: Double) -> String {
        AngleRules.normalizedDegrees(degrees)
            .formatted(.number.precision(.fractionLength(0 ... 2)))
    }
}
