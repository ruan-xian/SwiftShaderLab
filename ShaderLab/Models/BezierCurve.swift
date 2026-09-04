import Foundation

struct BezierCoordinate: Codable, Equatable, Sendable {
    var x: Double
    var y: Double

    static func interpolated(
        from start: BezierCoordinate,
        to end: BezierCoordinate,
        progress: Double
    ) -> BezierCoordinate {
        BezierCoordinate(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }
}

struct BezierAnchor: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var position: BezierCoordinate
    var incomingHandle: BezierCoordinate
    var outgoingHandle: BezierCoordinate
    var handlesLinked: Bool

    init(
        id: UUID = UUID(),
        position: BezierCoordinate,
        incomingHandle: BezierCoordinate,
        outgoingHandle: BezierCoordinate,
        handlesLinked: Bool = false
    ) {
        self.id = id
        self.position = position
        self.incomingHandle = incomingHandle
        self.outgoingHandle = outgoingHandle
        self.handlesLinked = handlesLinked
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case position
        case incomingHandle
        case outgoingHandle
        case handlesLinked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        position = try container.decode(BezierCoordinate.self, forKey: .position)
        incomingHandle = try container.decode(BezierCoordinate.self, forKey: .incomingHandle)
        outgoingHandle = try container.decode(BezierCoordinate.self, forKey: .outgoingHandle)
        handlesLinked = try container.decodeIfPresent(Bool.self, forKey: .handlesLinked) ?? false
    }
}

struct BezierCurveLookupTable: Equatable, Sendable {
    let inputRange: ClosedRange<Float>
    let samples: [Float]
}

struct BezierCurve: Codable, Equatable, Sendable {
    var points: [BezierAnchor]

    /// Evaluates the function value. Curve data should be sanitized before evaluation.
    func value(at input: Double) -> Double? {
        guard let first = points.first else { return nil }
        guard points.count > 1, let last = points.last else { return first.position.y }

        if input < first.position.x {
            return tangentValue(
                at: input,
                anchor: first.position,
                handle: first.incomingHandle
            )
        }
        if input > last.position.x {
            return tangentValue(
                at: input,
                anchor: last.position,
                handle: last.outgoingHandle
            )
        }

        for (start, end) in zip(points, points.dropFirst()) where input <= end.position.x {
            if input <= start.position.x { return start.position.y }
            let progress = parameter(
                for: input,
                start: start.position.x,
                control1: start.outgoingHandle.x,
                control2: end.incomingHandle.x,
                end: end.position.x
            )
            return cubic(
                progress,
                start.position.y,
                start.outgoingHandle.y,
                end.incomingHandle.y,
                end.position.y
            )
        }

        return last.position.y
    }

    /// Evaluates dy/dx without adding work to value-only evaluation.
    /// A vertical or effectively vertical tangent returns zero.
    func derivative(at input: Double) -> Double? {
        guard let first = points.first else { return nil }
        guard points.count > 1, let last = points.last else { return 0 }

        if input < first.position.x {
            return tangentSlope(anchor: first.position, handle: first.incomingHandle)
        }
        if input > last.position.x {
            return tangentSlope(anchor: last.position, handle: last.outgoingHandle)
        }

        let finalSegmentStart = points.index(points.endIndex, offsetBy: -2)
        for index in points.indices.dropLast() {
            let start = points[index]
            let end = points[index + 1]
            let isFinalSegment = index == finalSegmentStart
            guard input < end.position.x || isFinalSegment else { continue }
            let progress = parameter(
                for: input,
                start: start.position.x,
                control1: start.outgoingHandle.x,
                control2: end.incomingHandle.x,
                end: end.position.x
            )
            let deltaX = cubicDerivative(
                progress,
                start.position.x,
                start.outgoingHandle.x,
                end.incomingHandle.x,
                end.position.x
            )
            guard abs(deltaX) > 0.000_000_001 else { return 0 }
            let deltaY = cubicDerivative(
                progress,
                start.position.y,
                start.outgoingHandle.y,
                end.incomingHandle.y,
                end.position.y
            )
            return deltaY / deltaX
        }

        return 0
    }

    func lookupTable(
        in inputRange: ClosedRange<Double>,
        sampleCount: Int
    ) -> BezierCurveLookupTable {
        let count = max(sampleCount, 2)
        let width = inputRange.upperBound - inputRange.lowerBound
        let samples = (0 ..< count).map { index in
            let progress = Double(index) / Double(count - 1)
            let input = inputRange.lowerBound + width * progress
            return Float(value(at: input) ?? 0)
        }
        return BezierCurveLookupTable(
            inputRange: Float(inputRange.lowerBound) ... Float(inputRange.upperBound),
            samples: samples
        )
    }

    func derivativeLookupTable(
        in inputRange: ClosedRange<Double>,
        sampleCount: Int
    ) -> BezierCurveLookupTable {
        let count = max(sampleCount, 2)
        let width = inputRange.upperBound - inputRange.lowerBound
        let samples = (0 ..< count).map { index in
            let progress = Double(index) / Double(count - 1)
            let input = inputRange.lowerBound + width * progress
            return Float(derivative(at: input) ?? 0)
        }
        return BezierCurveLookupTable(
            inputRange: Float(inputRange.lowerBound) ... Float(inputRange.upperBound),
            samples: samples
        )
    }

    private func tangentValue(
        at input: Double,
        anchor: BezierCoordinate,
        handle: BezierCoordinate
    ) -> Double {
        let deltaX = handle.x - anchor.x
        guard abs(deltaX) > 0.000_000_001 else { return anchor.y }
        let slope = (handle.y - anchor.y) / deltaX
        return anchor.y + slope * (input - anchor.x)
    }

    private func tangentSlope(
        anchor: BezierCoordinate,
        handle: BezierCoordinate
    ) -> Double {
        let deltaX = handle.x - anchor.x
        guard abs(deltaX) > 0.000_000_001 else { return 0 }
        return (handle.y - anchor.y) / deltaX
    }

    private func parameter(
        for input: Double,
        start: Double,
        control1: Double,
        control2: Double,
        end: Double
    ) -> Double {
        var lower = 0.0
        var upper = 1.0
        for _ in 0 ..< 48 {
            let middle = (lower + upper) / 2
            if cubic(middle, start, control1, control2, end) < input {
                lower = middle
            } else {
                upper = middle
            }
        }
        return (lower + upper) / 2
    }

    private func cubic(
        _ progress: Double,
        _ start: Double,
        _ control1: Double,
        _ control2: Double,
        _ end: Double
    ) -> Double {
        let inverse = 1 - progress
        return inverse * inverse * inverse * start
            + 3 * inverse * inverse * progress * control1
            + 3 * inverse * progress * progress * control2
            + progress * progress * progress * end
    }

    private func cubicDerivative(
        _ progress: Double,
        _ start: Double,
        _ control1: Double,
        _ control2: Double,
        _ end: Double
    ) -> Double {
        let inverse = 1 - progress
        return 3 * inverse * inverse * (control1 - start)
            + 6 * inverse * progress * (control2 - control1)
            + 3 * progress * progress * (end - control2)
    }
}

struct BezierCurveExamples: Codable, Equatable, Sendable {
    var easing: BezierCurve
    var transfer: BezierCurve
    var partialDomain: BezierCurve

    static let defaults = BezierCurveExamples(
        easing: BezierCurve(points: [
            BezierAnchor(
                position: BezierCoordinate(x: 0, y: 0),
                incomingHandle: BezierCoordinate(x: -0.2, y: -0.05),
                outgoingHandle: BezierCoordinate(x: 0.2, y: 0.05),
                handlesLinked: true
            ),
            BezierAnchor(
                position: BezierCoordinate(x: 1, y: 1),
                incomingHandle: BezierCoordinate(x: 0.72, y: 0.95),
                outgoingHandle: BezierCoordinate(x: 1.28, y: 1.05),
                handlesLinked: true
            ),
        ]),
        transfer: BezierCurve(points: [
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
                position: BezierCoordinate(x: 0.68, y: 0.72),
                incomingHandle: BezierCoordinate(x: 0.56, y: -0.15),
                outgoingHandle: BezierCoordinate(x: 0.8, y: 0.92)
            ),
            BezierAnchor(
                position: BezierCoordinate(x: 1, y: 0.9),
                incomingHandle: BezierCoordinate(x: 0.9, y: 0.9),
                outgoingHandle: BezierCoordinate(x: 1.15, y: 0.9)
            ),
        ]),
        partialDomain: BezierCurve(points: [
            BezierAnchor(
                position: BezierCoordinate(x: 0.2, y: 0.18),
                incomingHandle: BezierCoordinate(x: -0.05, y: -0.1),
                outgoingHandle: BezierCoordinate(x: 0.3, y: 0.3)
            ),
            BezierAnchor(
                position: BezierCoordinate(x: 0.52, y: 0.78),
                incomingHandle: BezierCoordinate(x: 0.42, y: 0.7),
                outgoingHandle: BezierCoordinate(x: 0.62, y: 0.86),
                handlesLinked: true
            ),
            BezierAnchor(
                position: BezierCoordinate(x: 0.8, y: 0.45),
                incomingHandle: BezierCoordinate(x: 0.7, y: 0.6),
                outgoingHandle: BezierCoordinate(x: 1.05, y: 0.2)
            ),
        ])
    )
}

enum BezierCurveRules {
    static let minimumPointCount = 2

    static func sanitized(
        _ curve: BezierCurve,
        anchorXBounds: ClosedRange<Double>? = nil,
        anchorYBounds: ClosedRange<Double>? = nil,
        fallback: BezierCurve
    ) -> BezierCurve {
        var points = curve.points
        guard points.count >= minimumPointCount else {
            return sanitized(
                fallback,
                anchorXBounds: anchorXBounds,
                anchorYBounds: anchorYBounds,
                fallback: BezierCurveExamples.defaults.easing
            )
        }

        var usedIDs = Set<UUID>()
        for index in points.indices {
            if usedIDs.contains(points[index].id) {
                points[index].id = UUID()
            }
            usedIDs.insert(points[index].id)
        }

        points.sort { $0.position.x < $1.position.x }
        for index in points.indices {
            let oldPosition = points[index].position
            if let anchorXBounds {
                points[index].position.x = points[index].position.x.clamped(to: anchorXBounds)
            }
            if let anchorYBounds {
                points[index].position.y = points[index].position.y.clamped(to: anchorYBounds)
            }
            let deltaX = points[index].position.x - oldPosition.x
            let deltaY = points[index].position.y - oldPosition.y
            points[index].incomingHandle.x += deltaX
            points[index].incomingHandle.y += deltaY
            points[index].outgoingHandle.x += deltaX
            points[index].outgoingHandle.y += deltaY
        }

        enforceAnchorOrder(&points, within: anchorXBounds)
        enforceHandleOrder(&points)
        enforceLinkedHandles(&points)
        return BezierCurve(points: points)
    }

    static func insertingPoint(into curve: BezierCurve) -> (curve: BezierCurve, id: UUID?) {
        guard curve.points.count >= minimumPointCount else { return (curve, nil) }
        var segmentIndex = curve.points.startIndex
        var widestSegment = -Double.greatestFiniteMagnitude
        for index in curve.points.indices.dropLast() {
            let width = curve.points[index + 1].position.x - curve.points[index].position.x
            if width > widestSegment {
                segmentIndex = index
                widestSegment = width
            }
        }

        var points = curve.points
        let nextIndex = points.index(after: segmentIndex)
        let start = points[segmentIndex]
        let end = points[nextIndex]
        let first = BezierCoordinate.interpolated(
            from: start.position,
            to: start.outgoingHandle,
            progress: 0.5
        )
        let second = BezierCoordinate.interpolated(
            from: start.outgoingHandle,
            to: end.incomingHandle,
            progress: 0.5
        )
        let third = BezierCoordinate.interpolated(
            from: end.incomingHandle,
            to: end.position,
            progress: 0.5
        )
        let incoming = BezierCoordinate.interpolated(from: first, to: second, progress: 0.5)
        let outgoing = BezierCoordinate.interpolated(from: second, to: third, progress: 0.5)
        let position = BezierCoordinate.interpolated(from: incoming, to: outgoing, progress: 0.5)
        let newPoint = BezierAnchor(
            position: position,
            incomingHandle: incoming,
            outgoingHandle: outgoing,
            handlesLinked: true
        )

        points[segmentIndex].outgoingHandle = first
        points[segmentIndex].handlesLinked = false
        points[nextIndex].incomingHandle = third
        points[nextIndex].handlesLinked = false
        points.insert(newPoint, at: nextIndex)
        return (BezierCurve(points: points), newPoint.id)
    }

    private static func enforceAnchorOrder(
        _ points: inout [BezierAnchor],
        within bounds: ClosedRange<Double>?
    ) {
        let epsilon = max((bounds.map { $0.upperBound - $0.lowerBound } ?? 1) * 0.000_001, 1e-9)
        if let bounds, bounds.upperBound - bounds.lowerBound <= epsilon * Double(points.count - 1) {
            let step = (bounds.upperBound - bounds.lowerBound) / Double(points.count - 1)
            for index in points.indices {
                movePoint(
                    &points[index],
                    toX: bounds.lowerBound + Double(index) * step
                )
            }
            return
        }

        for index in points.indices.dropFirst() {
            movePoint(
                &points[index],
                toX: max(
                    points[index].position.x,
                    points[index - 1].position.x + epsilon
                )
            )
        }
        if let bounds, let overflow = points.last.map({ $0.position.x - bounds.upperBound }), overflow > 0 {
            for index in points.indices {
                movePoint(&points[index], toX: points[index].position.x - overflow)
            }
        }
    }

    private static func enforceHandleOrder(_ points: inout [BezierAnchor]) {
        for index in points.indices.dropLast() {
            let nextIndex = points.index(after: index)
            let lower = points[index].position.x
            let upper = points[nextIndex].position.x
            points[index].outgoingHandle.x = points[index].outgoingHandle.x.clamped(to: lower ... upper)
            points[nextIndex].incomingHandle.x = points[nextIndex].incomingHandle.x.clamped(
                to: points[index].outgoingHandle.x ... upper
            )
        }
    }

    private static func enforceLinkedHandles(_ points: inout [BezierAnchor]) {
        for index in points.indices where points[index].handlesLinked {
            let position = points[index].position
            let leftLimit = index > points.startIndex
                ? position.x - points[index - 1].outgoingHandle.x
                : Double.greatestFiniteMagnitude
            let rightLimit = index < points.index(before: points.endIndex)
                ? points[index + 1].incomingHandle.x - position.x
                : Double.greatestFiniteMagnitude
            let maximumRadius = max(min(leftLimit, rightLimit), 0)
            let radius = (points[index].outgoingHandle.x - position.x)
                .clamped(to: 0 ... maximumRadius)
            points[index].outgoingHandle.x = position.x + radius
            points[index].incomingHandle = mirrored(
                points[index].outgoingHandle,
                around: position
            )
        }
    }

    static func mirrored(
        _ coordinate: BezierCoordinate,
        around position: BezierCoordinate
    ) -> BezierCoordinate {
        BezierCoordinate(
            x: position.x * 2 - coordinate.x,
            y: position.y * 2 - coordinate.y
        )
    }

    private static func movePoint(_ point: inout BezierAnchor, toX x: Double) {
        let delta = x - point.position.x
        point.position.x = x
        point.incomingHandle.x += delta
        point.outgoingHandle.x += delta
    }
}
