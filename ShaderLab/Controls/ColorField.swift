import SwiftUI

struct ColorField: View {
    let title: String
    @Binding var color: SRGBAColor
    var defaultColor: SRGBAColor?

    @State private var hexText: String
    @FocusState private var isHexFieldFocused: Bool

    init(title: String, color: Binding<SRGBAColor>, defaultColor: SRGBAColor? = nil) {
        self.title = title
        _color = color
        self.defaultColor = defaultColor
        _hexText = State(initialValue: color.wrappedValue.hex)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            TextField("#RRGGBB", text: $hexText)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospaced())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .focused($isHexFieldFocused)
                .frame(width: 92)
                .onSubmit(commitHex)
                .accessibilityLabel("\(title) hex color")

            ColorPicker(title, selection: colorBinding, supportsOpacity: false)
                .labelsHidden()

            if let defaultColor {
                Button("Reset") {
                    color = defaultColor
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(color == defaultColor)
            }
        }
        .font(.caption)
        .onChange(of: color) { _, newValue in
            guard !isHexFieldFocused else { return }
            hexText = newValue.hex
        }
        .onChange(of: isHexFieldFocused) { _, isFocused in
            if !isFocused {
                commitHex()
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { color.color },
            set: { color = SRGBAColor(color: $0, fallback: color) }
        )
    }

    private func commitHex() {
        guard let parsed = SRGBAColor(hex: hexText) else {
            hexText = color.hex
            return
        }
        color = parsed
        hexText = parsed.hex
    }
}

struct HSVColorSliders: View {
    @Binding var color: SRGBAColor
    let defaultColor: SRGBAColor

    @State private var hue: Double

    init(color: Binding<SRGBAColor>, defaultColor: SRGBAColor) {
        _color = color
        self.defaultColor = defaultColor
        _hue = State(initialValue: color.wrappedValue.hsv.hue)
    }

    var body: some View {
        VStack(spacing: 12) {
            LabSlider(
                title: "Hue",
                value: hueBinding,
                defaultValue: defaultColor.hsv.hue * 360,
                range: 0 ... 359,
                fractionLength: 0,
                suffix: "°"
            )

            LabSlider(
                title: "Saturation",
                value: saturationBinding,
                defaultValue: defaultColor.hsv.saturation * 100,
                range: 0 ... 100,
                fractionLength: 0,
                suffix: "%"
            )

            LabSlider(
                title: "Value",
                value: valueBinding,
                defaultValue: defaultColor.hsv.value * 100,
                range: 0 ... 100,
                fractionLength: 0,
                suffix: "%"
            )
        }
        .onChange(of: color) { _, newColor in
            let hsv = newColor.hsv
            if hsv.saturation > 0.000_001 {
                hue = hsv.hue
            }
        }
    }

    private var hueBinding: Binding<Double> {
        Binding(
            get: { hue * 360 },
            set: { degrees in
                hue = degrees / 360
                updateColor(hue: hue)
            }
        )
    }

    private var saturationBinding: Binding<Double> {
        Binding(
            get: { color.hsv.saturation * 100 },
            set: { updateColor(saturation: $0 / 100) }
        )
    }

    private var valueBinding: Binding<Double> {
        Binding(
            get: { color.hsv.value * 100 },
            set: { updateColor(value: $0 / 100) }
        )
    }

    private func updateColor(
        hue: Double? = nil,
        saturation: Double? = nil,
        value: Double? = nil
    ) {
        var hsv = color.hsv
        hsv.hue = hue ?? self.hue
        hsv.saturation = saturation ?? hsv.saturation
        hsv.value = value ?? hsv.value
        color = SRGBAColor(hsv: hsv)
    }
}
