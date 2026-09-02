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

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    PreviewPane(document: store.document)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    inspector
                        .frame(width: min(max(geometry.size.width * 0.4, 420), 520))
                }
            } else {
                VStack(spacing: 0) {
                    PreviewPane(document: store.document)
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
            PreviewControlsView(settings: $store.document.preview)
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
    let document: ShaderLabDocument

    var body: some View {
        ZStack {
            PreviewBackground(settings: document.preview)
            ShaderPreviewView(settings: document.shader)
                .padding(36)
        }
        .clipped()
        .accessibilityElement(children: .contain)
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
                checkerboardControls

            case .image:
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

            LabSlider(
                title: "Checker scale",
                value: $settings.checkerScale,
                defaultValue: PreviewSettings.defaults.checkerScale,
                range: 12 ... 600,
                fractionLength: 0,
                scale: .logarithmic
            )
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
