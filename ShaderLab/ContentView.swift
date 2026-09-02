import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum ControlTab: String, CaseIterable, Identifiable {
    case shader = "Shader"
    case gradient = "Gradient"
    case preview = "Preview"

    var id: Self { self }
}

struct ContentView: View {
    @Bindable var store: ShaderLabStore

    @State private var selectedTab = ControlTab.shader
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = JSONFileDocument(data: Data())
    @State private var statusMessage: String?
    @State private var isRepositioningBackground = false

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    PreviewPane(
                        shaderSettings: store.document.shader,
                        previewSettings: $store.document.preview,
                        isRepositioningBackground: $isRepositioningBackground
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    inspector
                        .frame(width: min(max(geometry.size.width * 0.4, 420), 520))
                }
            } else {
                VStack(spacing: 0) {
                    PreviewPane(
                        shaderSettings: store.document.shader,
                        previewSettings: $store.document.preview,
                        isRepositioningBackground: $isRepositioningBackground
                    )
                    .frame(minHeight: 300)

                    Divider()

                    inspector
                        .frame(maxHeight: geometry.size.height * 0.52)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .onChange(of: selectedTab) { _, tab in
            if tab != .preview {
                isRepositioningBackground = false
            }
        }
        .onChange(of: store.document.preview.backgroundMode) {
            isRepositioningBackground = false
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) {
            importSettings(from: $0)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "ShaderLabSettings"
        ) { result in
            switch result {
            case .success:
                statusMessage = "Settings exported"
            case let .failure(error as CocoaError) where error.code == .userCancelled:
                statusMessage = "Export cancelled"
            case let .failure(error):
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private var inspector: some View {
        VStack(spacing: 0) {
            actionBar

            Divider()

            Picker("Controls", selection: $selectedTab) {
                ForEach(ControlTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], 16)

            ScrollView {
                controlPanel
                    .padding(16)
            }
        }
        .background(.regularMaterial)
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("Copy JSON", systemImage: "doc.on.doc") {
                    copySettings()
                }

                Button("Import", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }

                Button("Export", systemImage: "square.and.arrow.up") {
                    prepareExport()
                }

                Spacer()

                Button("Reset", systemImage: "arrow.counterclockwise", role: .destructive) {
                    isRepositioningBackground = false
                    store.reset()
                    statusMessage = "Defaults restored"
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)

            HStack {
                Text(statusMessage ?? "Changes save automatically")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityLabel(statusMessage ?? "Changes save automatically")
                Spacer()
            }
            .font(.caption)
        }
        .padding(12)
    }

    @ViewBuilder
    private var controlPanel: some View {
        switch selectedTab {
        case .shader:
            ShaderControlsView(settings: $store.document.shader)

        case .gradient:
            GradientEditor(
                stops: $store.document.shader.gradientStops,
                defaultStops: ShaderSettings.defaults.gradientStops
            )

        case .preview:
            PreviewControlsView(
                settings: $store.document.preview,
                isRepositioningBackground: $isRepositioningBackground
            )
        }
    }

    private func copySettings() {
        do {
            let data = try store.exportData()
            guard let json = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            UIPasteboard.general.string = json
            statusMessage = "JSON copied"
        } catch {
            statusMessage = "Copy failed: \(error.localizedDescription)"
        }
    }

    private func prepareExport() {
        do {
            exportDocument = try JSONFileDocument(data: store.exportData())
            isExporting = true
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importSettings(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try store.importData(Data(contentsOf: url))
            isRepositioningBackground = false
            statusMessage = "Settings imported"
        } catch let error as CocoaError where error.code == .userCancelled {
            statusMessage = "Import cancelled"
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

private struct PreviewPane: View {
    let shaderSettings: ShaderSettings
    @Binding var previewSettings: PreviewSettings
    @Binding var isRepositioningBackground: Bool

    @GestureState private var dragTranslation = CGSize.zero
    @GestureState private var magnification: CGFloat = 1
    @FocusState private var editSurfaceFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PreviewBackground(settings: displayedSettings(in: geometry.size))
                ShaderPreviewView(settings: shaderSettings)
                    .padding(36)

                if isRepositioningBackground {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(dragGesture(in: geometry.size))
                        .simultaneousGesture(magnifyGesture)

                    VStack {
                        Label(
                            "Drag to move · Pinch or use Scale",
                            systemImage: "arrow.up.and.down.and.arrow.left.and.right"
                        )
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())
                        .padding(12)

                        Spacer()
                    }
                    .allowsHitTesting(false)

                    Rectangle()
                        .stroke(.tint, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .focusable(isRepositioningBackground)
            .focused($editSurfaceFocused)
            .onKeyPress(phases: [.down, .repeat]) { keyPress in
                handleKeyPress(keyPress, in: geometry.size)
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .onChange(of: isRepositioningBackground) { _, isRepositioning in
            editSurfaceFocused = isRepositioning
        }
    }

    private func displayedSettings(in size: CGSize) -> PreviewSettings {
        var settings = previewSettings
        offset(
            settings: &settings,
            by: dragTranslation,
            in: size
        )
        scale(settings: &settings, by: magnification)
        return settings
    }

    private func offset(
        settings: inout PreviewSettings,
        by translation: CGSize,
        in size: CGSize
    ) {
        guard size.width > 0, size.height > 0 else { return }
        let x = Double(translation.width / size.width)
        let y = Double(translation.height / size.height)

        switch settings.backgroundMode {
        case .solid:
            break
        case .checkerboard:
            settings.checkerOffsetX += x
            settings.checkerOffsetY += y
        case .image:
            settings.imageOffsetX += x
            settings.imageOffsetY += y
        }
    }

    private func scale(settings: inout PreviewSettings, by magnification: CGFloat) {
        let magnification = Double(magnification)
        switch settings.backgroundMode {
        case .solid:
            break
        case .checkerboard:
            settings.checkerScale = (settings.checkerScale * magnification)
                .clamped(to: 12 ... 600)
        case .image:
            settings.imageScale = (settings.imageScale * magnification)
                .clamped(to: 0.25 ... 4)
        }
    }

    private func commitOffset(_ translation: CGSize, in size: CGSize) {
        var settings = previewSettings
        offset(settings: &settings, by: translation, in: size)
        previewSettings = settings
    }

    private func commitScale(_ magnification: CGFloat) {
        var settings = previewSettings
        scale(settings: &settings, by: magnification)
        previewSettings = settings
    }

    private func nudge(by translation: CGSize, in size: CGSize) {
        commitOffset(translation, in: size)
    }

    private func handleKeyPress(_ keyPress: KeyPress, in size: CGSize) -> KeyPress.Result {
        guard isRepositioningBackground else { return .ignored }

        if keyPress.key == .escape {
            isRepositioningBackground = false
            return .handled
        }

        let distance: CGFloat = keyPress.modifiers.contains(.shift) ? 10 : 1
        let translation: CGSize
        switch keyPress.key {
        case .leftArrow:
            translation = CGSize(width: -distance, height: 0)
        case .rightArrow:
            translation = CGSize(width: distance, height: 0)
        case .upArrow:
            translation = CGSize(width: 0, height: -distance)
        case .downArrow:
            translation = CGSize(width: 0, height: distance)
        default:
            return .ignored
        }

        nudge(by: translation, in: size)
        return .handled
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                commitOffset(value.translation, in: size)
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                commitScale(value.magnification)
            }
    }
}

private struct ShaderControlsView: View {
    @Binding var settings: ShaderSettings

    var body: some View {
        VStack(spacing: 16) {
            LabSlider(
                title: "Intensity",
                value: $settings.intensity,
                defaultValue: ShaderSettings.defaults.intensity,
                range: 0 ... 2
            )

            LabSlider(
                title: "Scale",
                value: $settings.scale,
                defaultValue: ShaderSettings.defaults.scale,
                range: 0.01 ... 100,
                scale: .logarithmic
            )

            LabSlider(
                title: "Speed",
                value: $settings.speed,
                defaultValue: ShaderSettings.defaults.speed,
                range: 0 ... 8,
                scale: .logarithmic
            )

            Text("Add shader-specific fields to ShaderSettings and compose their controls here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PreviewControlsView: View {
    @Binding var settings: PreviewSettings
    @Binding var isRepositioningBackground: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Background")
                Spacer()
                Picker("Background", selection: $settings.backgroundMode) {
                    ForEach(BackgroundMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            switch settings.backgroundMode {
            case .solid:
                ColorField(
                    title: "Solid color",
                    color: $settings.solidColor,
                    defaultColor: PreviewSettings.defaults.solidColor
                )

            case .checkerboard:
                placementControls
                checkerboardControls

            case .image:
                placementControls

                Text("Replace PreviewBackground.png in Assets.xcassets to customize this preset.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.caption)
    }

    private var checkerboardControls: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Checker style")
                Spacer()
                Picker("Checker style", selection: $settings.checkerMode) {
                    ForEach(CheckerboardMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Toggle("Number tiles", isOn: $settings.checkerShowsCoordinates)
        }
    }

    private var placementControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Placement")

                Spacer()

                Button("Center", systemImage: "scope") {
                    centerBackground()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isBackgroundCentered)

                Button(
                    isRepositioningBackground ? "Done" : "Reposition",
                    systemImage: isRepositioningBackground
                        ? "checkmark"
                        : "arrow.up.and.down.and.arrow.left.and.right"
                ) {
                    isRepositioningBackground.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            LabSlider(
                title: "Scale",
                value: backgroundScale,
                defaultValue: backgroundScaleDefault,
                range: backgroundScaleRange,
                fractionLength: 0,
                suffix: settings.backgroundMode == .image ? "%" : "pt",
                scale: .logarithmic
            )

            Text("Reposition enables dragging, arrow-key nudging, and trackpad pinch in the preview.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var backgroundScale: Binding<Double> {
        switch settings.backgroundMode {
        case .solid:
            .constant(1)
        case .checkerboard:
            $settings.checkerScale
        case .image:
            Binding(
                get: { settings.imageScale * 100 },
                set: { settings.imageScale = $0 / 100 }
            )
        }
    }

    private var backgroundScaleDefault: Double {
        switch settings.backgroundMode {
        case .solid:
            1
        case .checkerboard:
            PreviewSettings.defaults.checkerScale
        case .image:
            PreviewSettings.defaults.imageScale * 100
        }
    }

    private var backgroundScaleRange: ClosedRange<Double> {
        switch settings.backgroundMode {
        case .solid:
            1 ... 1
        case .checkerboard:
            12 ... 600
        case .image:
            25 ... 400
        }
    }

    private var isBackgroundCentered: Bool {
        switch settings.backgroundMode {
        case .solid:
            true
        case .checkerboard:
            settings.checkerOffsetX == 0 && settings.checkerOffsetY == 0
        case .image:
            settings.imageOffsetX == 0 && settings.imageOffsetY == 0
        }
    }

    private func centerBackground() {
        switch settings.backgroundMode {
        case .solid:
            break
        case .checkerboard:
            settings.checkerOffsetX = 0
            settings.checkerOffsetY = 0
        case .image:
            settings.imageOffsetX = 0
            settings.imageOffsetY = 0
        }
    }
}

private struct JSONFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
private struct ContentViewPreview: View {
    @State private var store = ShaderLabStore(
        document: .defaults,
        persistsChanges: false
    )

    var body: some View {
        ContentView(store: store)
            .frame(width: 1100, height: 760)
    }
}

#Preview("Shader Lab") {
    ContentViewPreview()
}
