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
        #expect(object["schemaVersion"] as? Int == 2)
        #expect(object["shader"] is [String: Any])
        #expect(object["preview"] is [String: Any])
        #expect((object["shader"] as? [String: Any])?["backgroundMode"] == nil)
        #expect((object["preview"] as? [String: Any])?["lightBrightness"] == nil)
    }

    @Test
    func shaderDefaultsUseTheBundledPreset() {
        let shader = ShaderSettings.defaults

        #expect(shader.diffuseGradientStops.count == 4)
        #expect(shader.diffuseGradientStops[1].location == 0.460_652_545_592_704_97)
        #expect(shader.gradientDirectionDegrees == 224.504_993_225_632_63)
        #expect(shader.lightDirectionDegrees == 127.411_743_488_141_8)
        #expect(shader.lightDistance == 2.339_202_404_022_217)
        #expect(shader.lightDepth == 1.710_318_788_202_911_6)
        #expect(shader.lightBrightness == 1.000_057_095_452_761_7)
        #expect(shader.ambientStrength == 0.231_389_954_686_164_86)
        #expect(
            shader.profileCurve.points.map(\.id) == [
                UUID(uuidString: "5C991F33-E86B-48FF-AF14-E6734A41306D")!,
                UUID(uuidString: "C301CEA1-6BDD-471E-8016-38F6935CCCE6")!,
            ]
        )
    }

    @Test
    func backgroundPlacementsRoundTripIndependently() throws {
        var document = ShaderLabDocument.defaults
        document.preview.isDarkMode = true
        document.preview.subjectScale = 1.35
        document.preview.isLocked = true
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
    func importedPreviewScalesAreClamped() throws {
        var document = ShaderLabDocument.defaults
        document.preview.subjectScale = 3
        document.preview.checkerScale = 1000
        document.preview.imageScale = 0.1

        let decoded = try ShaderLabDocument.decodeJSON(document.jsonData())

        #expect(decoded.preview.subjectScale == 2)
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
    func HSVConversionRoundTripsSRGBAColor() {
        let source = SRGBAColor(red: 0.27, green: 0.68, blue: 0.42, alpha: 0.8)
        let roundTrip = SRGBAColor(hsv: source.hsv)

        #expect(abs(roundTrip.red - source.red) < 0.000_001)
        #expect(abs(roundTrip.green - source.green) < 0.000_001)
        #expect(abs(roundTrip.blue - source.blue) < 0.000_001)
        #expect(abs(roundTrip.alpha - source.alpha) < 0.000_001)
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

    @Test
    func gradientInsertionAtLocationInterpolatesAndHonorsMaximum() throws {
        let black = SRGBAColor(red: 0, green: 0, blue: 0)
        let white = SRGBAColor(red: 1, green: 1, blue: 1)
        var stops = [
            ShaderGradientStop(location: 0, color: black),
            ShaderGradientStop(location: 1, color: white),
        ]

        stops = GradientRules.insertingStop(at: 0.25, into: stops)
        let inserted = try #require(stops.first { abs($0.location - 0.25) < 0.000_001 })
        #expect(abs(inserted.color.red - 0.25) < 0.000_001)

        for location in [0.4, 0.5, 0.6, 0.7, 0.8] {
            stops = GradientRules.insertingStop(at: location, into: stops)
        }
        #expect(stops.count == 8)
        #expect(GradientRules.insertingStop(at: 0.9, into: stops) == stops)
    }

    @Test
    func versionOneDocumentsLoadCompleteDefaults() throws {
        var document = ShaderLabDocument.defaults
        document.schemaVersion = 1
        document.shader.lightBrightness = 42
        document.preview.subjectScale = 1.8

        let decoded = try ShaderLabDocument.decodeJSON(document.jsonData())

        #expect(decoded == .defaults)
    }

    @Test
    func angleNormalizationUsesMathematicalDegrees() {
        #expect(AngleRules.normalizedDegrees(0) == 0)
        #expect(AngleRules.normalizedDegrees(90) == 90)
        #expect(AngleRules.normalizedDegrees(450) == 90)
        #expect(AngleRules.normalizedDegrees(-90) == 270)
        #expect(AngleRules.normalizedDegrees(-360) == 0)
        #expect(AngleRules.normalizedDegrees(.infinity) == 0)
    }

    @Test
    func bezierCurveEvaluatesSegmentsAndEndpointTangents() throws {
        let curve = linearBezierCurve()
        let zero = try #require(curve.value(at: 0))
        let midpoint = try #require(curve.value(at: 0.5))
        let one = try #require(curve.value(at: 1))

        #expect(abs(zero - 0) < 0.000_001)
        #expect(abs(midpoint - 0.5) < 0.000_001)
        #expect(abs(one - 1) < 0.000_001)

        var verticalTangent = curve
        verticalTangent.points[0].incomingHandle = BezierCoordinate(x: 0.2, y: -4)
        let extended = try #require(verticalTangent.value(at: 0))
        #expect(abs(extended - 0.2) < 0.000_001)
    }

    @Test
    func bezierSanitizationBoundsAnchorsButPreservesHandleOvershoot() {
        let curve = BezierCurve(points: [
            BezierAnchor(
                position: BezierCoordinate(x: -1, y: -1),
                incomingHandle: BezierCoordinate(x: -2, y: -3),
                outgoingHandle: BezierCoordinate(x: 0.9, y: 3)
            ),
            BezierAnchor(
                position: BezierCoordinate(x: 2, y: 2),
                incomingHandle: BezierCoordinate(x: 0.1, y: -2),
                outgoingHandle: BezierCoordinate(x: 3, y: 4)
            ),
        ])

        let result = BezierCurveRules.sanitized(
            curve,
            anchorXBounds: 0 ... 1,
            anchorYBounds: 0 ... 1,
            fallback: .sphericalProfile
        )

        #expect(result.points[0].position == BezierCoordinate(x: 0, y: 0))
        #expect(result.points[1].position == BezierCoordinate(x: 1, y: 1))
        #expect(result.points[0].outgoingHandle.x <= result.points[1].incomingHandle.x)
        #expect(result.points[0].outgoingHandle.y > 1)
        #expect(result.points[1].incomingHandle.y < 0)
    }

    @Test
    func bezierInsertionPreservesCurveShape() throws {
        let curve = multiPointBezierCurve()
        let insertion = BezierCurveRules.insertingPoint(into: curve)
        let insertedID = try #require(insertion.id)

        #expect(insertion.curve.points.count == curve.points.count + 1)
        #expect(insertion.curve.points.contains(where: { $0.id == insertedID }))
        #expect(insertion.curve.points.first(where: { $0.id == insertedID })?.handlesLinked == true)
        for sample in 0 ... 100 {
            let x = Double(sample) / 100
            let before = try #require(curve.value(at: x))
            let after = try #require(insertion.curve.value(at: x))
            #expect(abs(before - after) < 0.000_001)
        }
    }

    @Test
    func linkedBezierHandlesAreMirroredAroundTheirAnchor() {
        var curve = multiPointBezierCurve()
        curve.points[1].handlesLinked = true
        curve.points[1].outgoingHandle = BezierCoordinate(x: 0.44, y: 0.9)

        let result = BezierCurveRules.sanitized(
            curve,
            anchorXBounds: 0 ... 1,
            fallback: multiPointBezierCurve()
        )
        let point = result.points[1]
        let expectedIncoming = BezierCurveRules.mirrored(
            point.outgoingHandle,
            around: point.position
        )

        #expect(point.incomingHandle == expectedIncoming)
    }

    @Test
    func olderBezierAnchorsDecodeAsUnlinked() throws {
        let anchor = linearBezierCurve().points[0]
        let data = try JSONEncoder().encode(anchor)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "handlesLinked")

        let decoded = try JSONDecoder().decode(
            BezierAnchor.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        #expect(!decoded.handlesLinked)
    }

    @Test
    func bezierLookupTableIncludesDomainEndpointsAsFloats() {
        let table = linearBezierCurve().lookupTable(in: 0 ... 1, sampleCount: 5)

        #expect(table.inputRange == (0 ... 1))
        #expect(table.samples == [0, 0.25, 0.5, 0.75, 1])
    }

    @Test
    func bezierDerivativeEvaluatesSegmentsAndEndpointTangents() throws {
        let curve = linearBezierCurve()
        let leftExtension = try #require(curve.derivative(at: 0))
        let midpoint = try #require(curve.derivative(at: 0.5))
        let rightExtension = try #require(curve.derivative(at: 1))

        #expect(abs(leftExtension - 1) < 0.000_001)
        #expect(abs(midpoint - 1) < 0.000_001)
        #expect(abs(rightExtension - 1) < 0.000_001)
    }

    @Test
    func bezierDerivativeUsesZeroForVerticalTangents() throws {
        var curve = linearBezierCurve()
        curve.points[0].incomingHandle = BezierCoordinate(x: 0.2, y: -1)
        curve.points[0].outgoingHandle = BezierCoordinate(x: 0.2, y: 1)
        let extensionDerivative = try #require(curve.derivative(at: 0))
        let segmentDerivative = try #require(curve.derivative(at: 0.2))

        #expect(extensionDerivative == 0)
        #expect(segmentDerivative == 0)
    }

    @Test
    func bezierDerivativeLookupTableIsGeneratedOnlyWhenRequested() {
        let table = linearBezierCurve().derivativeLookupTable(in: 0 ... 1, sampleCount: 5)

        #expect(table.inputRange == (0 ... 1))
        #expect(table.samples == [1, 1, 1, 1, 1])
    }

    @Test @MainActor
    func malformedImportDoesNotReplaceCurrentDocument() {
        var document = ShaderLabDocument.defaults
        document.shader.lightBrightness = 1.37
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

    private func linearBezierCurve() -> BezierCurve {
        BezierCurve(points: [
            BezierAnchor(
                position: BezierCoordinate(x: 0.2, y: 0.2),
                incomingHandle: BezierCoordinate(x: 0, y: 0),
                outgoingHandle: BezierCoordinate(x: 0.4, y: 0.4)
            ),
            BezierAnchor(
                position: BezierCoordinate(x: 0.8, y: 0.8),
                incomingHandle: BezierCoordinate(x: 0.6, y: 0.6),
                outgoingHandle: BezierCoordinate(x: 1, y: 1)
            ),
        ])
    }

    private func multiPointBezierCurve() -> BezierCurve {
        BezierCurve(points: [
            BezierAnchor(
                position: BezierCoordinate(x: 0, y: 0.1),
                incomingHandle: BezierCoordinate(x: -0.15, y: 0.1),
                outgoingHandle: BezierCoordinate(x: 0.12, y: 0.1)
            ),
            BezierAnchor(
                position: BezierCoordinate(x: 0.32, y: 0.28),
                incomingHandle: BezierCoordinate(x: 0.22, y: 0.16),
                outgoingHandle: BezierCoordinate(x: 0.44, y: 1.2)
            ),
            BezierAnchor(
                position: BezierCoordinate(x: 1, y: 0.9),
                incomingHandle: BezierCoordinate(x: 0.8, y: 0.9),
                outgoingHandle: BezierCoordinate(x: 1.15, y: 0.9)
            ),
        ])
    }
}
