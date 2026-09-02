import SwiftUI

enum LabSliderScale {
    case linear
    case logarithmic
}

enum LogarithmicScale {
    static func normalized(value: Double, in range: ClosedRange<Double>) -> Double {
        guard range.upperBound > max(range.lowerBound, 0) else { return 0 }
        let logLower = effectiveLowerBound(for: range)
        guard value >= logLower else { return 0 }
        let lower = log(logLower)
        let upper = log(range.upperBound)
        return ((log(value.clamped(to: logLower ... range.upperBound)) - lower) / (upper - lower))
            .clamped(to: 0 ... 1)
    }

    static func value(normalized: Double, in range: ClosedRange<Double>) -> Double {
        let normalized = normalized.clamped(to: 0 ... 1)
        guard normalized > 0 else { return range.lowerBound }
        let logLower = effectiveLowerBound(for: range)
        let lower = log(logLower)
        let upper = log(range.upperBound)
        return exp(lower + normalized * (upper - lower)).clamped(to: range)
    }

    private static func effectiveLowerBound(for range: ClosedRange<Double>) -> Double {
        range.lowerBound > 0 ? range.lowerBound : range.upperBound / 10000
    }
}

struct LabSlider: View {
    let title: String
    @Binding var value: Double
    let defaultValue: Double
    let range: ClosedRange<Double>
    var step: Double?
    var fractionLength = 2
    var suffix = ""
    var scale = LabSliderScale.linear

    private var sliderBinding: Binding<Double> {
        switch scale {
        case .linear:
            $value
        case .logarithmic:
            Binding(
                get: { LogarithmicScale.normalized(value: value, in: range) },
                set: { value = LogarithmicScale.value(normalized: $0, in: range) }
            )
        }
    }

    private var sliderRange: ClosedRange<Double> {
        scale == .linear ? range : 0 ... 1
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value, format: .number.precision(.fractionLength(fractionLength)))
                    .monospacedDigit()
                if !suffix.isEmpty {
                    Text(suffix)
                        .foregroundStyle(.secondary)
                }
                Button("Reset") {
                    value = defaultValue
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(abs(value - defaultValue) < 0.000_001)
            }
            .font(.caption)

            slider
                .accessibilityLabel(title)
                .accessibilityValue(
                    Text(value, format: .number.precision(.fractionLength(fractionLength)))
                )
        }
    }

    @ViewBuilder
    private var slider: some View {
        if let step, scale == .linear {
            Slider(value: sliderBinding, in: sliderRange, step: step)
        } else {
            Slider(value: sliderBinding, in: sliderRange)
        }
    }
}
