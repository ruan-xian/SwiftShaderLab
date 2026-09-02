import SwiftUI

@main
struct ShaderLabApp: App {
    @State private var store = ShaderLabStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .shaderLabWindowSizing()
        }
    }
}

private extension View {
    @ViewBuilder
    func shaderLabWindowSizing() -> some View {
        #if targetEnvironment(macCatalyst)
            frame(
                minWidth: 1000,
                maxWidth: .infinity,
                minHeight: 700,
                maxHeight: .infinity
            )
        #else
            self
        #endif
    }
}
