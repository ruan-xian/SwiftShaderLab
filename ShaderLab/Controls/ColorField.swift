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
