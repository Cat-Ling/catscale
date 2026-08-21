import SwiftUI

public struct ContentView: View {
    @State private var state = AppState()

    public init() {}

    public var body: some View {
        TabView {
            Tab("Upscale", systemImage: "wand.and.stars") {
                UpscaleView(state: state)
            }

            Tab("Batch", systemImage: "square.stack.3d.up.fill") {
                BatchUpscaleView(state: state)
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView(state: state)
            }
        }
        .tint(.accentColor)
    }
}
