import SwiftUI
import UIKit

struct BezierCurveEditorConfiguration {
    let domainX: ClosedRange<Double>
    let domainY: ClosedRange<Double>
    var anchorXBounds: ClosedRange<Double>?
    var anchorYBounds: ClosedRange<Double>?
    var sampleCount = 256

    init(
        domainX: ClosedRange<Double>,
        domainY: ClosedRange<Double>,
        anchorXBounds: ClosedRange<Double>? = nil,
        anchorYBounds: ClosedRange<Double>? = nil,
        sampleCount: Int = 256
    ) {
        self.domainX = domainX
        self.domainY = domainY
        self.anchorXBounds = anchorXBounds
        self.anchorYBounds = anchorYBounds
        self.sampleCount = max(sampleCount, 2)
    }
}

enum BezierExamplePalette {
    static let easing = Color.cyan
    static let transfer = Color.orange
    static let partialDomain = Color.pink
}

struct BezierExamplesView: View {
    @Binding var examples: BezierCurveExamples

    var body: some View {
        VStack(spacing: 16) {
            BezierCurveEditor(
                title: "Easing",
                curve: $examples.easing,
                defaultCurve: BezierCurveExamples.defaults.easing,
                configuration: BezierCurveEditorConfiguration(
                    domainX: 0 ... 1,
                    domainY: 0 ... 1,
                    anchorXBounds: 0 ... 1,
                    anchorYBounds: 0 ... 1
                ),
                tint: BezierExamplePalette.easing
            )

            BezierCurveEditor(
                title: "Transfer",
                curve: $examples.transfer,
                defaultCurve: BezierCurveExamples.defaults.transfer,
                configuration: BezierCurveEditorConfiguration(
                    domainX: 0 ... 1,
                    domainY: 0 ... 1,
                    anchorXBounds: 0 ... 1
                ),
                tint: BezierExamplePalette.transfer
            )

            BezierCurveEditor(
                title: "Partial Domain",
                curve: $examples.partialDomain,
                defaultCurve: BezierCurveExamples.defaults.partialDomain,
                configuration: BezierCurveEditorConfiguration(
                    domainX: 0 ... 1,
                    domainY: 0 ... 1,
                    anchorXBounds: 0.15 ... 0.85,
                    anchorYBounds: 0 ... 1
                ),
                tint: BezierExamplePalette.partialDomain
            )

            Text("Each editor produces a Float lookup table for shader or MTKView upload.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BezierCurveEditor: View {
    private enum EditableCoordinate: Equatable {
        case position
        case incomingHandle
        case outgoingHandle
    }

    private static let canvasHeight: CGFloat = 260
    private static let plotInset: CGFloat = 18
    private static let zoomRange = 0.0001 ... 100.0

    let title: String
    @Binding var curve: BezierCurve
    let defaultCurve: BezierCurve
    let configuration: BezierCurveEditorConfiguration
    let tint: Color

    @State private var selectedID: UUID?
    @State private var viewportCenter: BezierCoordinate
    @State private var zoom = 1.0
    @State private var trackpadTranslation = CGSize.zero
    @GestureState private var magnification: CGFloat = 1

    init(
        title: String,
        curve: Binding<BezierCurve>,
        defaultCurve: BezierCurve,
        configuration: BezierCurveEditorConfiguration,
        tint: Color
    ) {
        self.title = title
        _curve = curve
        self.defaultCurve = defaultCurve
        self.configuration = configuration
        self.tint = tint
        _viewportCenter = State(
            initialValue: BezierCoordinate(
                x: (configuration.domainX.lowerBound + configuration.domainX.upperBound) / 2,
                y: (configuration.domainY.lowerBound + configuration.domainY.upperBound) / 2
            )
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            editorCanvas

            if let selectedID, curve.points.contains(where: { $0.id == selectedID }) {
                coordinateEditor(for: selectedID)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            sanitizeCurve()
            selectValidPoint()
        }
        .onChange(of: curve.points.map(\.id)) { _, _ in
            selectValidPoint()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(title)
            Text("\(curve.points.count)")
                .foregroundStyle(.secondary)
            Spacer()

            Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right") {
                fitContent()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.mini)

            Button("Reset") {
                curve = defaultCurve
                selectedID = curve.points.first?.id
                resetViewport()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(curve == defaultCurve)

            Button("Add point", systemImage: "plus") {
                let insertion = BezierCurveRules.insertingPoint(into: curve)
                curve = insertion.curve
                selectedID = insertion.id ?? selectedID
                sanitizeCurve()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.mini)

            Button("Remove point", systemImage: "minus", role: .destructive) {
                removeSelectedPoint()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(curve.points.count <= BezierCurveRules.minimumPointCount || selectedID == nil)
        }
        .font(.caption)
    }

    private var editorCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))

                curveCanvas(size: geometry.size)

                BezierPanSurface(
                    onChanged: { trackpadTranslation = $0 },
                    onEnded: { translation in
                        commitPan(translation, in: geometry.size)
                        trackpadTranslation = .zero
                    },
                    onCancelled: { trackpadTranslation = .zero }
                )

                ForEach(curve.points) { point in
                    if point.id != selectedID {
                        inactiveHandleNode(point.incomingHandle, in: geometry.size)
                        inactiveHandleNode(point.outgoingHandle, in: geometry.size)
                    }
                }

                ForEach(curve.points) { point in
                    anchorNode(point, in: geometry.size)
                }

                if let selectedPoint {
                    handleNode(
                        selectedPoint.incomingHandle,
                        kind: .incomingHandle,
                        pointID: selectedPoint.id,
                        in: geometry.size
                    )
                    handleNode(
                        selectedPoint.outgoingHandle,
                        kind: .outgoingHandle,
                        pointID: selectedPoint.id,
                        in: geometry.size
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3))
                    .allowsHitTesting(false)
            }
            .coordinateSpace(name: "BezierCurveEditorCanvas")
            .simultaneousGesture(magnifyGesture)
        }
        .frame(height: Self.canvasHeight)
        .accessibilityLabel("\(title) Bézier curve")
    }

    private func curveCanvas(size: CGSize) -> some View {
        Canvas { context, _ in
            drawGrid(context: &context, size: size)

            for point in curve.points {
                var handles = Path()
                handles.move(to: screenPoint(point.position, in: size))
                handles.addLine(to: screenPoint(point.incomingHandle, in: size))
                handles.move(to: screenPoint(point.position, in: size))
                handles.addLine(to: screenPoint(point.outgoingHandle, in: size))
                let isSelected = point.id == selectedID
                context.stroke(
                    handles,
                    with: .color(tint.opacity(isSelected ? 0.55 : 0.08)),
                    style: StrokeStyle(lineWidth: isSelected ? 1 : 0.75, dash: [4, 3])
                )
            }

            let table = curve.lookupTable(
                in: configuration.domainX,
                sampleCount: configuration.sampleCount
            )
            var path = Path()
            for index in table.samples.indices {
                let progress = Double(index) / Double(max(table.samples.count - 1, 1))
                let x = configuration.domainX.lowerBound
                    + (configuration.domainX.upperBound - configuration.domainX.lowerBound) * progress
                let point = screenPoint(
                    BezierCoordinate(x: x, y: Double(table.samples[index])),
                    in: size
                )
                if index == table.samples.startIndex {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            context.stroke(path, with: .color(tint), lineWidth: 3)
        }
        .allowsHitTesting(false)
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        let domainCorners = [
            BezierCoordinate(x: configuration.domainX.lowerBound, y: configuration.domainY.lowerBound),
            BezierCoordinate(x: configuration.domainX.upperBound, y: configuration.domainY.upperBound),
        ]
        let first = screenPoint(domainCorners[0], in: size)
        let second = screenPoint(domainCorners[1], in: size)
        let domainRect = CGRect(
            x: min(first.x, second.x),
            y: min(first.y, second.y),
            width: abs(second.x - first.x),
            height: abs(second.y - first.y)
        )
        context.stroke(
            Path(domainRect),
            with: .color(Color.secondary.opacity(0.4)),
            lineWidth: 1
        )

        for division in 1 ..< 4 {
            let progress = Double(division) / 4
            let x = configuration.domainX.lowerBound
                + (configuration.domainX.upperBound - configuration.domainX.lowerBound) * progress
            let y = configuration.domainY.lowerBound
                + (configuration.domainY.upperBound - configuration.domainY.lowerBound) * progress
            var gridLine = Path()
            gridLine.move(
                to: screenPoint(
                    BezierCoordinate(x: x, y: configuration.domainY.lowerBound),
                    in: size
                )
            )
            gridLine.addLine(
                to: screenPoint(
                    BezierCoordinate(x: x, y: configuration.domainY.upperBound),
                    in: size
                )
            )
            gridLine.move(
                to: screenPoint(
                    BezierCoordinate(x: configuration.domainX.lowerBound, y: y),
                    in: size
                )
            )
            gridLine.addLine(
                to: screenPoint(
                    BezierCoordinate(x: configuration.domainX.upperBound, y: y),
                    in: size
                )
            )
            context.stroke(gridLine, with: .color(Color.secondary.opacity(0.14)), lineWidth: 1)
        }
    }

    private func anchorNode(_ point: BezierAnchor, in size: CGSize) -> some View {
        Circle()
            .fill(point.id == selectedID ? tint : Color(uiColor: .systemBackground))
            .frame(width: 16, height: 16)
            .overlay { Circle().stroke(tint, lineWidth: 2) }
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .contentShape(Rectangle().inset(by: -8))
            .position(screenPoint(point.position, in: size))
            .gesture(coordinateDragGesture(pointID: point.id, kind: .position, in: size))
            .accessibilityElement()
            .accessibilityLabel("Anchor")
            .accessibilityValue(coordinateDescription(point.position))
            .accessibilityAddTraits(point.id == selectedID ? .isSelected : [])
            .accessibilityAdjustableAction { direction in
                selectedID = point.id
                let step = (configuration.domainY.upperBound - configuration.domainY.lowerBound) / 100
                let delta = direction == .increment ? step : -step
                updateCoordinate(
                    pointID: point.id,
                    kind: .position,
                    proposed: BezierCoordinate(x: point.position.x, y: point.position.y + delta)
                )
            }
    }

    private func handleNode(
        _ coordinate: BezierCoordinate,
        kind: EditableCoordinate,
        pointID: UUID,
        in size: CGSize
    ) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(tint)
            .frame(width: 11, height: 11)
            .contentShape(Rectangle().inset(by: -8))
            .position(screenPoint(coordinate, in: size))
            .gesture(coordinateDragGesture(pointID: pointID, kind: kind, in: size))
            .accessibilityElement()
            .accessibilityLabel(kind == .incomingHandle ? "Incoming handle" : "Outgoing handle")
            .accessibilityValue(coordinateDescription(coordinate))
    }

    private func inactiveHandleNode(_ coordinate: BezierCoordinate, in size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(tint.opacity(0.14))
            .frame(width: 9, height: 9)
            .position(screenPoint(coordinate, in: size))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func coordinateEditor(for pointID: UUID) -> some View {
        VStack(spacing: 7) {
            Toggle(isOn: handlesLinkedBinding(for: pointID)) {
                Label("Link Handles", systemImage: "link")
            }
            coordinateRow("Point", pointID: pointID, kind: .position)
            coordinateRow("Handle 1", pointID: pointID, kind: .incomingHandle)
            coordinateRow("Handle 2", pointID: pointID, kind: .outgoingHandle)
        }
        .font(.caption)
    }

    private func coordinateRow(
        _ label: String,
        pointID: UUID,
        kind: EditableCoordinate
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .frame(width: 58, alignment: .leading)
            Text("x")
                .foregroundStyle(.secondary)
            TextField("x", value: coordinateBinding(pointID: pointID, kind: kind, isX: true), format: .number.precision(.fractionLength(3)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 88)
            Text("y")
                .foregroundStyle(.secondary)
            TextField("y", value: coordinateBinding(pointID: pointID, kind: kind, isX: false), format: .number.precision(.fractionLength(3)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 88)
        }
    }

    private var selectedPoint: BezierAnchor? {
        guard let selectedID else { return nil }
        return curve.points.first { $0.id == selectedID }
    }

    private var effectiveZoom: Double {
        (zoom * Double(magnification)).clamped(to: Self.zoomRange)
    }

    private func visibleRanges(in size: CGSize) -> (x: ClosedRange<Double>, y: ClosedRange<Double>) {
        let rect = plotRect(in: size)
        let xSpan = (configuration.domainX.upperBound - configuration.domainX.lowerBound) / effectiveZoom
        let ySpan = (configuration.domainY.upperBound - configuration.domainY.lowerBound) / effectiveZoom
        let translation = trackpadTranslation
        let centerX = viewportCenter.x - Double(translation.width / max(rect.width, 1)) * xSpan
        let centerY = viewportCenter.y + Double(translation.height / max(rect.height, 1)) * ySpan
        return (
            (centerX - xSpan / 2) ... (centerX + xSpan / 2),
            (centerY - ySpan / 2) ... (centerY + ySpan / 2)
        )
    }

    private func plotRect(in size: CGSize) -> CGRect {
        CGRect(
            x: Self.plotInset,
            y: Self.plotInset,
            width: max(size.width - Self.plotInset * 2, 1),
            height: max(size.height - Self.plotInset * 2, 1)
        )
    }

    private func screenPoint(_ coordinate: BezierCoordinate, in size: CGSize) -> CGPoint {
        let rect = plotRect(in: size)
        let ranges = visibleRanges(in: size)
        let xProgress = (coordinate.x - ranges.x.lowerBound)
            / max(ranges.x.upperBound - ranges.x.lowerBound, .leastNonzeroMagnitude)
        let yProgress = (coordinate.y - ranges.y.lowerBound)
            / max(ranges.y.upperBound - ranges.y.lowerBound, .leastNonzeroMagnitude)
        return CGPoint(
            x: rect.minX + CGFloat(xProgress) * rect.width,
            y: rect.maxY - CGFloat(yProgress) * rect.height
        )
    }

    private func curveCoordinate(at location: CGPoint, in size: CGSize) -> BezierCoordinate {
        let rect = plotRect(in: size)
        let ranges = visibleRanges(in: size)
        let xProgress = Double((location.x - rect.minX) / max(rect.width, 1))
        let yProgress = Double((rect.maxY - location.y) / max(rect.height, 1))
        return BezierCoordinate(
            x: ranges.x.lowerBound + (ranges.x.upperBound - ranges.x.lowerBound) * xProgress,
            y: ranges.y.lowerBound + (ranges.y.upperBound - ranges.y.lowerBound) * yProgress
        )
    }

    private func coordinateDragGesture(
        pointID: UUID,
        kind: EditableCoordinate,
        in size: CGSize
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("BezierCurveEditorCanvas"))
            .onChanged { value in
                selectedID = pointID
                updateCoordinate(
                    pointID: pointID,
                    kind: kind,
                    proposed: curveCoordinate(at: value.location, in: size)
                )
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                zoom = (zoom * Double(value.magnification)).clamped(to: Self.zoomRange)
            }
    }

    private func commitPan(_ translation: CGSize, in size: CGSize) {
        let rect = plotRect(in: size)
        let ranges = visibleRanges(in: size)
        viewportCenter.x -= Double(translation.width / max(rect.width, 1))
            * (ranges.x.upperBound - ranges.x.lowerBound)
        viewportCenter.y += Double(translation.height / max(rect.height, 1))
            * (ranges.y.upperBound - ranges.y.lowerBound)
    }

    private func coordinateBinding(
        pointID: UUID,
        kind: EditableCoordinate,
        isX: Bool
    ) -> Binding<Double> {
        Binding(
            get: {
                guard let point = curve.points.first(where: { $0.id == pointID }) else { return 0 }
                let coordinate = coordinate(for: point, kind: kind)
                return isX ? coordinate.x : coordinate.y
            },
            set: { value in
                guard let point = curve.points.first(where: { $0.id == pointID }) else { return }
                var coordinate = coordinate(for: point, kind: kind)
                if isX {
                    coordinate.x = value
                } else {
                    coordinate.y = value
                }
                updateCoordinate(pointID: pointID, kind: kind, proposed: coordinate)
            }
        )
    }

    private func coordinate(
        for point: BezierAnchor,
        kind: EditableCoordinate
    ) -> BezierCoordinate {
        switch kind {
        case .position: point.position
        case .incomingHandle: point.incomingHandle
        case .outgoingHandle: point.outgoingHandle
        }
    }

    private func updateCoordinate(
        pointID: UUID,
        kind: EditableCoordinate,
        proposed: BezierCoordinate
    ) {
        guard let index = curve.points.firstIndex(where: { $0.id == pointID }) else { return }
        switch kind {
        case .position:
            let oldPosition = curve.points[index].position
            let constrained = constrainedPosition(proposed, at: index)
            let deltaX = constrained.x - oldPosition.x
            let deltaY = constrained.y - oldPosition.y
            curve.points[index].position = constrained
            curve.points[index].incomingHandle.x += deltaX
            curve.points[index].incomingHandle.y += deltaY
            curve.points[index].outgoingHandle.x += deltaX
            curve.points[index].outgoingHandle.y += deltaY
        case .incomingHandle:
            if curve.points[index].handlesLinked {
                updateLinkedHandle(proposed, at: index, kind: .incomingHandle)
            } else {
                curve.points[index].incomingHandle = constrainedHandle(
                    proposed,
                    at: index,
                    kind: .incomingHandle
                )
            }
        case .outgoingHandle:
            if curve.points[index].handlesLinked {
                updateLinkedHandle(proposed, at: index, kind: .outgoingHandle)
            } else {
                curve.points[index].outgoingHandle = constrainedHandle(
                    proposed,
                    at: index,
                    kind: .outgoingHandle
                )
            }
        }
        sanitizeCurve()
    }

    private func constrainedPosition(_ proposed: BezierCoordinate, at index: Int) -> BezierCoordinate {
        var result = proposed
        let spacing = max(
            (configuration.domainX.upperBound - configuration.domainX.lowerBound) * 0.000_001,
            1e-9
        )
        let lower = index > curve.points.startIndex
            ? curve.points[index - 1].position.x + spacing
            : configuration.anchorXBounds?.lowerBound ?? -.greatestFiniteMagnitude
        let upper = index < curve.points.index(before: curve.points.endIndex)
            ? curve.points[index + 1].position.x - spacing
            : configuration.anchorXBounds?.upperBound ?? .greatestFiniteMagnitude
        result.x = result.x.clamped(to: lower ... upper)
        if let bounds = configuration.anchorXBounds {
            result.x = result.x.clamped(to: bounds)
        }
        if let bounds = configuration.anchorYBounds {
            result.y = result.y.clamped(to: bounds)
        }
        return result
    }

    private func updateLinkedHandle(
        _ proposed: BezierCoordinate,
        at index: Int,
        kind: EditableCoordinate
    ) {
        let position = curve.points[index].position
        let maximumRadius = linkedHandleMaximumRadius(at: index)
        var coordinate = proposed
        switch kind {
        case .incomingHandle:
            let radius = (position.x - proposed.x).clamped(to: 0 ... maximumRadius)
            coordinate.x = position.x - radius
            curve.points[index].incomingHandle = coordinate
            curve.points[index].outgoingHandle = BezierCurveRules.mirrored(
                coordinate,
                around: position
            )
        case .outgoingHandle:
            let radius = (proposed.x - position.x).clamped(to: 0 ... maximumRadius)
            coordinate.x = position.x + radius
            curve.points[index].outgoingHandle = coordinate
            curve.points[index].incomingHandle = BezierCurveRules.mirrored(
                coordinate,
                around: position
            )
        case .position:
            break
        }
    }

    private func linkedHandleMaximumRadius(at index: Int) -> Double {
        let position = curve.points[index].position
        let leftLimit = index > curve.points.startIndex
            ? position.x - curve.points[index - 1].outgoingHandle.x
            : Double.greatestFiniteMagnitude
        let rightLimit = index < curve.points.index(before: curve.points.endIndex)
            ? curve.points[index + 1].incomingHandle.x - position.x
            : Double.greatestFiniteMagnitude
        return max(min(leftLimit, rightLimit), 0)
    }

    private func handlesLinkedBinding(for pointID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                curve.points.first(where: { $0.id == pointID })?.handlesLinked ?? false
            },
            set: { isLinked in
                guard let index = curve.points.firstIndex(where: { $0.id == pointID }) else { return }
                curve.points[index].handlesLinked = isLinked
                if isLinked {
                    updateLinkedHandle(
                        curve.points[index].outgoingHandle,
                        at: index,
                        kind: .outgoingHandle
                    )
                }
                sanitizeCurve()
            }
        )
    }

    private func constrainedHandle(
        _ proposed: BezierCoordinate,
        at index: Int,
        kind: EditableCoordinate
    ) -> BezierCoordinate {
        var result = proposed
        switch kind {
        case .incomingHandle where index > curve.points.startIndex:
            result.x = result.x.clamped(
                to: curve.points[index - 1].outgoingHandle.x ... curve.points[index].position.x
            )
        case .outgoingHandle where index < curve.points.index(before: curve.points.endIndex):
            result.x = result.x.clamped(
                to: curve.points[index].position.x ... curve.points[index + 1].incomingHandle.x
            )
        default:
            break
        }
        return result
    }

    private func sanitizeCurve() {
        curve = BezierCurveRules.sanitized(
            curve,
            anchorXBounds: configuration.anchorXBounds,
            anchorYBounds: configuration.anchorYBounds,
            fallback: defaultCurve
        )
    }

    private func removeSelectedPoint() {
        guard curve.points.count > BezierCurveRules.minimumPointCount,
              let selectedID,
              let index = curve.points.firstIndex(where: { $0.id == selectedID })
        else { return }
        curve.points.remove(at: index)
        self.selectedID = curve.points[min(index, curve.points.index(before: curve.points.endIndex))].id
        sanitizeCurve()
    }

    private func selectValidPoint() {
        if let selectedID, curve.points.contains(where: { $0.id == selectedID }) { return }
        selectedID = curve.points.first?.id
    }

    private func fitContent() {
        let coordinates = curve.points.flatMap {
            [$0.position, $0.incomingHandle, $0.outgoingHandle]
        } + [
            BezierCoordinate(x: configuration.domainX.lowerBound, y: configuration.domainY.lowerBound),
            BezierCoordinate(x: configuration.domainX.upperBound, y: configuration.domainY.upperBound),
        ]
        guard let minX = coordinates.map(\.x).min(),
              let maxX = coordinates.map(\.x).max(),
              let minY = coordinates.map(\.y).min(),
              let maxY = coordinates.map(\.y).max()
        else { return }
        viewportCenter = BezierCoordinate(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let xRatio = (configuration.domainX.upperBound - configuration.domainX.lowerBound)
            / max((maxX - minX) * 1.15, 0.000_001)
        let yRatio = (configuration.domainY.upperBound - configuration.domainY.lowerBound)
            / max((maxY - minY) * 1.15, 0.000_001)
        zoom = min(xRatio, yRatio).clamped(to: Self.zoomRange)
    }

    private func resetViewport() {
        viewportCenter = BezierCoordinate(
            x: (configuration.domainX.lowerBound + configuration.domainX.upperBound) / 2,
            y: (configuration.domainY.lowerBound + configuration.domainY.upperBound) / 2
        )
        zoom = 1
        trackpadTranslation = .zero
    }

    private func coordinateDescription(_ coordinate: BezierCoordinate) -> String {
        "x \(coordinate.x.formatted(.number.precision(.fractionLength(3)))), "
            + "y \(coordinate.y.formatted(.number.precision(.fractionLength(3))))"
    }
}

private struct BezierPanSurface: UIViewRepresentable {
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded, onCancelled: onCancelled)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let recognizer = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        recognizer.allowedScrollTypesMask = .continuous
        recognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
    }

    final class Coordinator: NSObject {
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
            default:
                break
            }
        }
    }
}
