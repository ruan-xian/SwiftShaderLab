import Foundation
import SwiftUI
import UIKit

struct ShaderLabDocument: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var shader: ShaderSettings
    var preview: PreviewSettings

    static let defaults = ShaderLabDocument(
        schemaVersion: currentSchemaVersion,
        shader: .defaults,
        preview: .defaults
    )

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case shader
        case preview
    }

    init(schemaVersion: Int, shader: ShaderSettings, preview: PreviewSettings) {
        self.schemaVersion = schemaVersion
        self.shader = shader
        self.preview = preview
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)

        if schemaVersion == 1 {
            self = Self.defaults
            return
        }

        guard schemaVersion == Self.currentSchemaVersion else {
            throw ShaderLabDocumentError.unsupportedSchemaVersion(schemaVersion)
        }

        try self.init(
            schemaVersion: schemaVersion,
            shader: container.decode(ShaderSettings.self, forKey: .shader),
            preview: container.decode(PreviewSettings.self, forKey: .preview)
        )
    }

    func validated() throws -> ShaderLabDocument {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ShaderLabDocumentError.unsupportedSchemaVersion(schemaVersion)
        }

        var result = self
        result.shader.gradientDirectionDegrees = AngleRules.normalizedDegrees(
            result.shader.gradientDirectionDegrees
        )
        result.shader.lightDirectionDegrees = AngleRules.normalizedDegrees(
            result.shader.lightDirectionDegrees
        )
        result.shader.diffuseGradientStops = GradientRules.sanitized(
            result.shader.diffuseGradientStops
        )
        result.shader.lightDistance = result.shader.lightDistance.clamped(to: 0 ... 4)
        result.shader.lightDepth = result.shader.lightDepth.clamped(to: 0.05 ... 4)
        result.shader.lightBrightness = result.shader.lightBrightness.clamped(to: 0.01 ... 100)
        result.shader.ambientStrength = result.shader.ambientStrength.clamped(to: 0 ... 1)
        result.shader.profileCurve = BezierCurveRules.sanitized(
            result.shader.profileCurve,
            anchorXBounds: 0 ... 1,
            fallback: ShaderSettings.defaults.profileCurve
        )
        result.preview.subjectScale = result.preview.subjectScale.clamped(to: 0.1 ... 2)
        result.preview.checkerScale = result.preview.checkerScale.clamped(to: 12 ... 600)
        result.preview.imageScale = result.preview.imageScale.clamped(to: 0.25 ... 4)
        return result
    }

    func jsonData(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        }
        return try encoder.encode(self)
    }

    static func decodeJSON(_ data: Data) throws -> ShaderLabDocument {
        try JSONDecoder().decode(Self.self, from: data).validated()
    }
}

enum ShaderLabDocumentError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            "Unsupported shader lab schema version: \(version)"
        }
    }
}

struct ShaderSettings: Codable, Equatable {
    var diffuseGradientStops: [ShaderGradientStop]
    var gradientDirectionDegrees: Double
    var lightDirectionDegrees: Double
    var lightDistance: Double
    var lightDepth: Double
    var lightBrightness: Double
    var lightColor: SRGBAColor
    var ambientStrength: Double
    var ambientColor: SRGBAColor
    var profileCurve: BezierCurve

    static let defaults = ShaderSettings(
        diffuseGradientStops: [
            ShaderGradientStop(
                id: UUID(uuidString: "11BD0452-76DD-4A0B-B028-B43350DBC343")!,
                location: 0,
                color: SRGBAColor(
                    red: 0.273_385_256_528_854_37,
                    green: 0.949_712_336_063_385,
                    blue: 0.791_919_291_019_439_7
                )
            ),
            ShaderGradientStop(
                id: UUID(uuidString: "FCD44C7C-20D9-4C2D-9726-EC1307F84560")!,
                location: 0.460_652_545_592_704_97,
                color: SRGBAColor(
                    red: 0.827_219_307_422_637_9,
                    green: 0.574_528_872_966_766_4,
                    blue: 0.344_620_645_046_234_13
                )
            ),
            ShaderGradientStop(
                id: UUID(uuidString: "6313D71E-73AA-4590-BFA5-DCE8DA958395")!,
                location: 0.835_000_604_448_742_6,
                color: SRGBAColor(
                    red: 0.938_915_093_479_479_1,
                    green: 0.346_637_430_137_652_8,
                    blue: 0.599_637_629_696_040_2
                )
            ),
            ShaderGradientStop(
                id: UUID(uuidString: "CC642E6D-E4E1-4A41-92F9-4F420FE2B5C1")!,
                location: 1,
                color: SRGBAColor(
                    red: 0.914_308_130_741_119_4,
                    green: 0.183_461_338_281_631_47,
                    blue: 0.783_367_097_377_777_1
                )
            ),
        ],
        gradientDirectionDegrees: 224.504_993_225_632_63,
        lightDirectionDegrees: 127.411_743_488_141_8,
        lightDistance: 2.339_202_404_022_217,
        lightDepth: 1.710_318_788_202_911_6,
        lightBrightness: 1.000_057_095_452_761_7,
        lightColor: SRGBAColor(red: 1, green: 1, blue: 1),
        ambientStrength: 0.231_389_954_686_164_86,
        ambientColor: SRGBAColor(red: 1, green: 1, blue: 1),
        profileCurve: .sphericalProfile
    )
}

struct PreviewSettings: Codable, Equatable {
    var isDarkMode: Bool
    var subjectScale: Double
    var backgroundMode: BackgroundMode
    var isLocked: Bool
    var solidColor: SRGBAColor
    var checkerMode: CheckerboardMode
    var checkerScale: Double
    var checkerShowsCoordinates: Bool
    var checkerOffsetX: Double
    var checkerOffsetY: Double
    var imageAsset: BackgroundImageAsset
    var imageOffsetX: Double
    var imageOffsetY: Double
    var imageScale: Double

    static let defaults = PreviewSettings(
        isDarkMode: false,
        subjectScale: 1,
        backgroundMode: .solid,
        isLocked: false,
        solidColor: SRGBAColor(red: 0.13, green: 0.13, blue: 0.15),
        checkerMode: .blackWhite,
        checkerScale: 96,
        checkerShowsCoordinates: false,
        checkerOffsetX: 0,
        checkerOffsetY: 0,
        imageAsset: .waves,
        imageOffsetX: 0,
        imageOffsetY: 0,
        imageScale: 1
    )

    private enum CodingKeys: String, CodingKey {
        case isDarkMode
        case subjectScale
        case backgroundMode
        case isLocked
        case solidColor
        case checkerMode
        case checkerScale
        case checkerShowsCoordinates
        case checkerOffsetX
        case checkerOffsetY
        case imageAsset
        case imageOffsetX
        case imageOffsetY
        case imageScale
    }
}

extension PreviewSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isDarkMode = try container.decodeIfPresent(Bool.self, forKey: .isDarkMode) ?? false
        subjectScale = try container.decodeIfPresent(Double.self, forKey: .subjectScale) ?? 1
        backgroundMode = try container.decode(BackgroundMode.self, forKey: .backgroundMode)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        solidColor = try container.decode(SRGBAColor.self, forKey: .solidColor)
        checkerMode = try container.decode(CheckerboardMode.self, forKey: .checkerMode)
        checkerScale = try container.decode(Double.self, forKey: .checkerScale)
        checkerShowsCoordinates = try container.decode(Bool.self, forKey: .checkerShowsCoordinates)
        checkerOffsetX = try container.decode(Double.self, forKey: .checkerOffsetX)
        checkerOffsetY = try container.decode(Double.self, forKey: .checkerOffsetY)
        imageAsset = try container.decode(BackgroundImageAsset.self, forKey: .imageAsset)
        imageOffsetX = try container.decode(Double.self, forKey: .imageOffsetX)
        imageOffsetY = try container.decode(Double.self, forKey: .imageOffsetY)
        imageScale = try container.decode(Double.self, forKey: .imageScale)
    }
}

enum BackgroundMode: String, Codable, CaseIterable, Identifiable {
    case solid
    case checkerboard
    case image

    var id: Self { self }

    var title: String {
        switch self {
        case .solid: "Solid"
        case .checkerboard: "Checkerboard"
        case .image: "Image"
        }
    }
}

enum CheckerboardMode: String, Codable, CaseIterable, Identifiable {
    case blackWhite
    case rainbowWhite
    case rainbowBlack

    var id: Self { self }

    var title: String {
        switch self {
        case .blackWhite: "Black + White"
        case .rainbowWhite: "Rainbow + White"
        case .rainbowBlack: "Rainbow + Black"
        }
    }
}

enum BackgroundImageAsset: String, Codable, CaseIterable, Identifiable {
    // Add image sets here to make them available in the background picker.
    case waves = "PreviewBackground"

    var id: Self { self }
    var imageName: String { rawValue }

    var title: String {
        switch self {
        case .waves: "Waves"
        }
    }
}

struct ShaderGradientStop: Codable, Equatable, Identifiable {
    var id: UUID
    var location: Double
    var color: SRGBAColor

    init(id: UUID = UUID(), location: Double, color: SRGBAColor) {
        self.id = id
        self.location = location
        self.color = color
    }
}

struct HSVColor: Equatable {
    var hue: Double
    var saturation: Double
    var value: Double
    var alpha: Double
}

struct SRGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red.clamped(to: 0 ... 1)
        self.green = green.clamped(to: 0 ... 1)
        self.blue = blue.clamped(to: 0 ... 1)
        self.alpha = alpha.clamped(to: 0 ... 1)
    }

    init(color: Color, fallback: SRGBAColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            self = fallback
            return
        }
        self.init(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }

    init(hsv: HSVColor) {
        let uiColor = UIColor(
            hue: hsv.hue.clamped(to: 0 ... 1),
            saturation: hsv.saturation.clamped(to: 0 ... 1),
            brightness: hsv.value.clamped(to: 0 ... 1),
            alpha: hsv.alpha.clamped(to: 0 ... 1)
        )
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }

    init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var hsv: HSVColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var value: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).getHue(
            &hue,
            saturation: &saturation,
            brightness: &value,
            alpha: &alpha
        )
        return HSVColor(
            hue: Double(hue),
            saturation: Double(saturation),
            value: Double(value),
            alpha: Double(alpha)
        )
    }

    var hex: String {
        String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    static func interpolated(from: SRGBAColor, to: SRGBAColor, progress: Double) -> Self {
        let progress = progress.clamped(to: 0 ... 1)
        return Self(
            red: from.red + (to.red - from.red) * progress,
            green: from.green + (to.green - from.green) * progress,
            blue: from.blue + (to.blue - from.blue) * progress,
            alpha: from.alpha + (to.alpha - from.alpha) * progress
        )
    }
}

enum GradientRules {
    static let minimumStopCount = 2
    static let maximumStopCount = 8
    static let minimumSpacing = 0.01

    static func sanitized(_ stops: [ShaderGradientStop]) -> [ShaderGradientStop] {
        var result = stops
            .prefix(maximumStopCount)
            .map {
                ShaderGradientStop(
                    id: $0.id,
                    location: $0.location.clamped(to: 0 ... 1),
                    color: $0.color
                )
            }
            .sorted { $0.location < $1.location }

        if result.isEmpty {
            result = ShaderSettings.defaults.diffuseGradientStops
        } else if result.count == 1 {
            let color = result[0].color
            result = [
                ShaderGradientStop(location: 0, color: color),
                ShaderGradientStop(location: 1, color: color),
            ]
        }

        for index in result.indices.dropFirst() {
            result[index].location = max(
                result[index].location,
                min(result[index - 1].location + minimumSpacing, 1)
            )
        }
        return result
    }

    static func insertingStop(into stops: [ShaderGradientStop]) -> [ShaderGradientStop] {
        let stops = sanitized(stops)
        guard stops.count < maximumStopCount else { return stops }

        let boundaries = [0.0] + stops.map(\.location) + [1.0]
        let widest = zip(boundaries, boundaries.dropFirst())
            .map { (lower: $0.0, upper: $0.1, width: $0.1 - $0.0) }
            .max { $0.width < $1.width }
        guard let widest, widest.width >= minimumSpacing * 2 else { return stops }

        return insertingStop(at: (widest.lower + widest.upper) / 2, into: stops)
    }

    static func insertingStop(
        at proposedLocation: Double,
        into stops: [ShaderGradientStop]
    ) -> [ShaderGradientStop] {
        let stops = sanitized(stops)
        guard stops.count < maximumStopCount else { return stops }

        let location = proposedLocation.clamped(to: 0 ... 1)
        guard stops.allSatisfy({ abs($0.location - location) >= minimumSpacing }) else {
            return stops
        }

        var result = stops
        result.append(ShaderGradientStop(location: location, color: color(at: location, in: stops)))
        return result.sorted { $0.location < $1.location }
    }

    static func color(at location: Double, in stops: [ShaderGradientStop]) -> SRGBAColor {
        let stops = sanitized(stops)
        guard let first = stops.first, let last = stops.last else {
            return SRGBAColor(red: 0, green: 0, blue: 0)
        }
        guard location > first.location else { return first.color }
        guard location < last.location else { return last.color }

        for pair in zip(stops, stops.dropFirst()) where location <= pair.1.location {
            let width = max(pair.1.location - pair.0.location, .leastNonzeroMagnitude)
            return SRGBAColor.interpolated(
                from: pair.0.color,
                to: pair.1.color,
                progress: (location - pair.0.location) / width
            )
        }
        return last.color
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
