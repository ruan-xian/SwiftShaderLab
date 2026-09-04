import Foundation

enum AngleRules {
    /// Normalizes mathematical degrees to `0..<360`.
    /// Zero points along the positive x-axis (right), and positive angles turn counterclockwise.
    static func normalizedDegrees(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        if remainder == 0 { return 0 }
        return remainder >= 0 ? remainder : remainder + 360
    }
}
