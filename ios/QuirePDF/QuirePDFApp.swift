import SwiftUI

@main
struct QuirePDFApp: App {
    init() {
        ScreenState.removeLeftovers()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
