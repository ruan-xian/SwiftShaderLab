import SwiftUI

struct GradientEditor: View {
    private static let handleWidth: CGFloat = 18

    @Binding var stops: [ShaderGradientStop]
    let defaultStops: [ShaderGradientStop]

    @State private var selectedID: UUID?

    var body: some View {
        VStack(spacing: 12) {
            header
            gradientTrack

            if let selectedBinding {
                ColorField(
                    title: "Selected stop",
                    color: selectedBinding.color
                )
                .id(selectedBinding.wrappedValue.id)

                HStack {
                    Text("Location")
                    Spacer()
                    TextField(
                        "Location",
                        value: locationPercentageBinding(for: selectedBinding.wrappedValue.id),
                        format: .number.precision(.fractionLength(1))
                    )
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 72)
                    Text("%")
                }
                .font(.caption)
            }
        }
        .onAppear {
            stops = GradientRules.sanitized(stops)
            selectValidStop()
        }
        .onChange(of: stops.map(\.id)) { _, _ in selectValidStop() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Gradient Stops")
            Text("\(stops.count)/\(GradientRules.maximumStopCount)")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reset") {
                stops = defaultStops
                selectedID = stops.first?.id
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(stops == defaultStops)

            Button("Add", systemImage: "plus") {
                let oldIDs = Set(stops.map(\.id))
                stops = GradientRules.insertingStop(into: stops)
                selectedID = stops.first { !oldIDs.contains($0.id) }?.id ?? selectedID
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(stops.count >= GradientRules.maximumStopCount)

            Button("Remove", systemImage: "minus", role: .destructive) {
                removeSelectedStop()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(stops.count <= GradientRules.minimumStopCount || selectedID == nil)
        }
        .font(.caption)
    }

    private var gradientTrack: some View {
        GeometryReader { geometry in
            let inset = Self.handleWidth / 2
            let trackWidth = max(geometry.size.width - Self.handleWidth, 1)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            stops: stops.map {
                                Gradient.Stop(
                                    color: $0.color.color,
                                    location: CGFloat($0.location.clamped(to: 0 ... 1))
                                )
                            },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay { RoundedRectangle(cornerRadius: 6).stroke(.primary.opacity(0.3)) }
                    .frame(width: trackWidth, height: 30)
                    .offset(x: inset)

                ForEach(stops) { stop in
                    stopHandle(stop)
                        .position(
                            x: inset + CGFloat(stop.location) * trackWidth,
                            y: 39
                        )
                        .gesture(
                            DragGesture(
                                minimumDistance: 0,
                                coordinateSpace: .named("ShaderLabGradientTrack")
                            )
                            .onChanged { value in
                                selectedID = stop.id
                                updateLocation(
                                    id: stop.id,
                                    proposed: Double((value.location.x - inset) / trackWidth)
                                )
                            }
                        )
                        .accessibilityElement()
                        .accessibilityLabel("Gradient stop")
                        .accessibilityValue(
                            Text(stop.location, format: .percent.precision(.fractionLength(0)))
                        )
                        .accessibilityAddTraits(stop.id == selectedID ? .isSelected : [])
                        .accessibilityAdjustableAction { direction in
                            selectedID = stop.id
                            let delta = direction == .increment ? 0.01 : -0.01
                            updateLocation(id: stop.id, proposed: stop.location + delta)
                        }
                }
            }
            .coordinateSpace(name: "ShaderLabGradientTrack")
        }
        .frame(height: 54)
        .accessibilityLabel("Shader gradient")
    }

    private func stopHandle(_ stop: ShaderGradientStop) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(stop.color.color)
            .frame(width: Self.handleWidth, height: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        stop.id == selectedID ? Color.primary : Color.black.opacity(0.65),
                        lineWidth: stop.id == selectedID ? 3 : 1
                    )
            }
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .contentShape(Rectangle())
    }

    private var selectedBinding: Binding<ShaderGradientStop>? {
        guard let selectedID,
              let index = stops.firstIndex(where: { $0.id == selectedID })
        else { return nil }
        return $stops[index]
    }

    private func locationPercentageBinding(for id: UUID) -> Binding<Double> {
        Binding(
            get: { (stops.first { $0.id == id }?.location ?? 0) * 100 },
            set: { updateLocation(id: id, proposed: $0 / 100) }
        )
    }

    private func updateLocation(id: UUID, proposed: Double) {
        guard let index = stops.firstIndex(where: { $0.id == id }) else { return }
        let lower = index == stops.startIndex
            ? 0
            : stops[index - 1].location + GradientRules.minimumSpacing
        let upper = index == stops.index(before: stops.endIndex)
            ? 1
            : stops[index + 1].location - GradientRules.minimumSpacing
        guard lower <= upper else { return }
        stops[index].location = proposed.clamped(to: lower ... upper)
    }

    private func removeSelectedStop() {
        guard stops.count > GradientRules.minimumStopCount,
              let selectedID,
              let index = stops.firstIndex(where: { $0.id == selectedID })
        else { return }
        stops.remove(at: index)
        self.selectedID = stops[min(index, stops.index(before: stops.endIndex))].id
    }

    private func selectValidStop() {
        if let selectedID, stops.contains(where: { $0.id == selectedID }) { return }
        selectedID = stops.first?.id
    }
}
