import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum ControlTab: String, CaseIterable, Identifiable {
    case shader = "Shader"
    case gradient = "Gradient"
    case bezier = "Bézier"

    var id: Self { self }
}

struct ContentView: View {
    @Bindable var store: ShaderLabStore

    @State private var selectedTab = ControlTab.shader
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = JSONFileDocument(data: Data())
    @State private var statusMessage: String?
    @State private var isPreviewControlsExpanded = false

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    previewPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    inspector
                        .frame(width: min(max(geometry.size.width * 0.4, 420), 520))
                }
            } else {
                VStack(spacing: 0) {
                    previewPanel
                    .frame(minHeight: 300)

                    Divider()

                    inspector
                        .frame(maxHeight: geometry.size.height * 0.52)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
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

    private var previewPanel: some View {
        VStack(spacing: 0) {
            PreviewPane(
                shaderSettings: store.document.shader,
                previewSettings: $store.document.preview
            )
            .environment(\.colorScheme, store.document.preview.isDarkMode ? .dark : .light)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        PreviewControlsView(settings: $store.document.preview)
                        .padding(16)
                    }
                    .frame(height: 360)
                    .offset(y: isPreviewControlsExpanded ? 0 : 360)
                }
                .frame(height: isPreviewControlsExpanded ? 360 : 0, alignment: .bottom)
                .clipped()
                .allowsHitTesting(isPreviewControlsExpanded)

                HStack(spacing: 12) {
                    Button(action: togglePreviewControls) {
                        Label("Preview Controls", systemImage: "rectangle.on.rectangle")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Text("Subject Scale")
                        .font(.caption)
                        .lineLimit(1)

                    Slider(
                        value: $store.document.preview.subjectScale,
                        in: 0.1 ... 2,
                        step: 0.05
                    )
                    .frame(minWidth: 64, idealWidth: 120, maxWidth: 160)
                    .accessibilityLabel("Subject Scale")
                    .accessibilityValue(
                        Text(
                            store.document.preview.subjectScale,
                            format: .percent.precision(.fractionLength(0))
                        )
                    )

                    Toggle(isOn: $store.document.preview.isDarkMode) {
                        Image(
                            systemName: store.document.preview.isDarkMode
                                ? "moon.fill"
                                : "sun.max.fill"
                        )
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Dark Mode")
                    .accessibilityValue(store.document.preview.isDarkMode ? "Dark" : "Light")

                    Toggle(isOn: $store.document.preview.isLocked) {
                        Image(
                            systemName: store.document.preview.isLocked ? "lock.fill" : "lock.open"
                        )
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Lock")
                    .accessibilityValue(store.document.preview.isLocked ? "Locked" : "Unlocked")

                    Button(action: togglePreviewControls) {
                        Image(systemName: "chevron.up")
                            .rotationEffect(.degrees(isPreviewControlsExpanded ? 180 : 0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Preview controls")
                    .accessibilityValue(isPreviewControlsExpanded ? "Expanded" : "Collapsed")
                }
                .font(.headline)
                .padding(16)
            }
            .background(.regularMaterial)
            .clipped()
        }
    }

    private func togglePreviewControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPreviewControlsExpanded.toggle()
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
                    store.reset()
                    statusMessage = "Defaults restored"
                }
            }
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

        case .bezier:
            BezierExamplesView(examples: $store.document.shader.bezierCurves)
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

    @GestureState private var dragTranslation = CGSize.zero
    @GestureState private var magnification: CGFloat = 1
    @State private var trackpadTranslation = CGSize.zero
    @FocusState private var editSurfaceFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let subjectScale = CGFloat(previewSettings.subjectScale)
            let subjectWidth = max(geometry.size.width - 72, 0) * subjectScale
            let subjectHeight = max(geometry.size.height - 72, 0) * subjectScale

            ZStack {
                PreviewBackground(settings: displayedSettings(in: geometry.size))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        ShaderPreviewView(settings: shaderSettings)
                            .frame(width: subjectWidth, height: subjectHeight)
                    }

                if isBackgroundInteractionEnabled {
                    TrackpadPanSurface(
                        onChanged: { trackpadTranslation = $0 },
                        onEnded: { translation in
                            commitOffset(translation, in: geometry.size)
                            trackpadTranslation = .zero
                        },
                        onCancelled: { trackpadTranslation = .zero }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(in: geometry.size))
                    .simultaneousGesture(magnifyGesture)

                    VStack {
                        Label(
                            "Drag or two-finger pan to move · Pinch or use Scale",
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
            .focusable(isBackgroundInteractionEnabled)
            .focused($editSurfaceFocused)
            .onKeyPress(phases: [.down, .repeat]) { keyPress in
                handleKeyPress(keyPress, in: geometry.size)
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .onChange(of: isBackgroundInteractionEnabled) { _, isEnabled in
            editSurfaceFocused = isEnabled
            if !isEnabled {
                trackpadTranslation = .zero
            }
        }
    }

    private var isBackgroundInteractionEnabled: Bool {
        !previewSettings.isLocked && previewSettings.backgroundMode != .solid
    }

    private func displayedSettings(in size: CGSize) -> PreviewSettings {
        var settings = previewSettings
        offset(
            settings: &settings,
            by: dragTranslation,
            in: size
        )
        offset(
            settings: &settings,
            by: trackpadTranslation,
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
        guard isBackgroundInteractionEnabled else { return .ignored }

        if keyPress.key == .escape {
            previewSettings.isLocked = true
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

private struct TrackpadPanSurface: UIViewRepresentable {
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let recognizer = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        recognizer.allowedScrollTypesMask = .continuous
        recognizer.allowedTouchTypes = []
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)

        return view
    }

    func updateUIView(_: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGSize) -> Void
        var onEnded: (CGSize) -> Void
        var onCancelled: () -> Void

        init(
            onChanged: @escaping (CGSize) -> Void,
            onEnded: @escaping (CGSize) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            let size = CGSize(width: translation.x, height: translation.y)

            switch recognizer.state {
            case .began, .changed:
                onChanged(size)
            case .ended:
                onEnded(size)
            case .cancelled, .failed:
                onCancelled()
            case .possible:
                break
            @unknown default:
                onCancelled()
            }
        }

        func gestureRecognizer(
            _: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
        ) -> Bool {
            true
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

            AngleControl(
                title: "Angle",
                angleDegrees: $settings.angleDegrees,
                defaultAngleDegrees: ShaderSettings.defaults.angleDegrees
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
    @State private var isImageAssetPickerPresented = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Background")
                Spacer()

                ForEach(BackgroundMode.allCases) { option in
                    backgroundModeButton(option)
                }
            }

            switch settings.backgroundMode {
            case .solid:
                ColorField(
                    title: "Solid color",
                    color: $settings.solidColor,
                    defaultColor: PreviewSettings.defaults.solidColor
                )

                HSVColorSliders(
                    color: $settings.solidColor,
                    defaultColor: PreviewSettings.defaults.solidColor
                )

            case .checkerboard:
                placementControls
                checkerboardControls

            case .image:
                imageAssetPicker
                placementControls

                Text("Add image sets to BackgroundImageAsset to include them in this picker.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.caption)
    }

    private func backgroundModeButton(_ option: BackgroundMode) -> some View {
        let isSelected = settings.backgroundMode == option

        return Button {
            settings.backgroundMode = option
        } label: {
            Label(
                option.title,
                systemImage: isSelected ? "largecircle.fill.circle" : "circle"
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        .accessibilityLabel(option.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var imageAssetPicker: some View {
        HStack {
            Text("Image")

            Spacer()

            Button {
                isImageAssetPickerPresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(settings.imageAsset.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    Text(settings.imageAsset.title)
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isImageAssetPickerPresented, arrowEdge: .trailing) {
                imageAssetGrid
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityLabel("Background image")
            .accessibilityValue(settings.imageAsset.title)
        }
    }

    private var imageAssetGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose an image")
                .font(.headline)

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 112), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(BackgroundImageAsset.allCases) { asset in
                        imageAssetButton(asset)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 360, height: 240)
    }

    private func imageAssetButton(_ asset: BackgroundImageAsset) -> some View {
        let isSelected = settings.imageAsset == asset

        return Button {
            settings.imageAsset = asset
            isImageAssetPickerPresented = false
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(asset.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(5)
                        }
                    }

                Text(asset.title)
                    .lineLimit(1)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(asset.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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

            Text("When unlocked, drag, use the arrow keys, or pinch the trackpad in the preview.")
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
