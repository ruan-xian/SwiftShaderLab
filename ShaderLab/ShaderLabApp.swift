import SwiftUI

@main
struct ShaderLabApp: App {
    @State private var store = ShaderLabStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
