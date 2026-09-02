import Foundation
@testable import ShaderLab
import Testing

struct ShaderLabTests {
    @Test
    func documentRoundTripKeepsShaderAndPreviewSeparated() throws {
        let data = try ShaderLabDocument.defaults.jsonData()
        let decoded = try ShaderLabDocument.decodeJSON(data)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(decoded == .defaults)
        #expect(object["schemaVersion"] as? Int == 1)
        #expect(object["shader"] is [String: Any])
        #expect(object["preview"] is [String: Any])
        #expect((object["shader"] as? [String: Any])?["backgroundMode"] == nil)
        #expect((object["preview"] as? [String: Any])?["intensity"] == nil)
    }

    @Test
    func backgroundPlacementsRoundTripIndependently() throws {
        var document = ShaderLabDocument.defaults
        document.preview.checkerOffsetX = 0.2
        document.preview.checkerOffsetY = -0.35
        document.preview.checkerScale = 144
        document.preview.imageOffsetX = -0.6
        document.preview.imageOffsetY = 0.45
        document.preview.imageScale = 2.25

        let decoded = try ShaderLabDocument.decodeJSON(document.jsonData())

        #expect(decoded.preview == document.preview)
    }

    @Test
    func importedBackgroundScalesAreClamped() throws {
        var document = ShaderLabDocument.defaults
        document.preview.checkerScale = 1000
        document.preview.imageScale = 0.1

        let decoded = try ShaderLabDocument.decodeJSON(document.jsonData())

        #expect(decoded.preview.checkerScale == 600)
        #expect(decoded.preview.imageScale == 0.25)
    }

    @Test
    func hexParsingNormalizesShortAndLongForms() throws {
        let short = try #require(SRGBAColor(hex: "#3af"))
        let long = try #require(SRGBAColor(hex: "33AAFF"))

        #expect(short == long)
        #expect(short.hex == "#33AAFF")
        #expect(SRGBAColor(hex: "not-a-color") == nil)
    }

    @Test
    func logarithmicScaleRoundTripsAndRepresentsZero() {
        let range = 0.0 ... 8.0

        #expect(LogarithmicScale.normalized(value: 0, in: range) == 0)
        #expect(LogarithmicScale.value(normalized: 0, in: range) == 0)
        #expect(abs(LogarithmicScale.value(normalized: 1, in: range) - 8) < 0.000_001)

        let value = 0.42
        let normalized = LogarithmicScale.normalized(value: value, in: range)
        #expect(abs(LogarithmicScale.value(normalized: normalized, in: range) - value) < 0.000_001)
    }

    @Test
    func gradientInsertionUsesWidestGapAndInterpolatesColor() throws {
        let black = SRGBAColor(red: 0, green: 0, blue: 0)
        let white = SRGBAColor(red: 1, green: 1, blue: 1)
        let stops = [
            ShaderGradientStop(location: 0, color: black),
            ShaderGradientStop(location: 1, color: white),
        ]

        let inserted = GradientRules.insertingStop(into: stops)
        let middle = try #require(inserted.first { abs($0.location - 0.5) < 0.000_001 })

        #expect(inserted.count == 3)
        #expect(abs(middle.color.red - 0.5) < 0.000_001)
        #expect(abs(middle.color.green - 0.5) < 0.000_001)
        #expect(abs(middle.color.blue - 0.5) < 0.000_001)
    }

    @Test @MainActor
    func malformedImportDoesNotReplaceCurrentDocument() {
        var document = ShaderLabDocument.defaults
        document.shader.intensity = 1.37
        let store = ShaderLabStore(document: document, persistsChanges: false)

        do {
            try store.importData(Data("{ definitely-not-json".utf8))
            Issue.record("Malformed JSON unexpectedly imported")
        } catch {
            #expect(store.document == document)
        }
    }

    @Test
    func unsupportedSchemaVersionIsRejected() throws {
        var document = ShaderLabDocument.defaults
        document.schemaVersion = 99
        let data = try document.jsonData()

        do {
            _ = try ShaderLabDocument.decodeJSON(data)
            Issue.record("Unsupported schema unexpectedly decoded")
        } catch let error as ShaderLabDocumentError {
            #expect(error == .unsupportedSchemaVersion(99))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
