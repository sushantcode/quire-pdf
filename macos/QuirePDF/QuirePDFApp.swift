import QuireKit
import SwiftUI

@main
struct QuirePDFApp: App {
    @State private var session = MergeSession()
    @State private var window = WindowState()

    var body: some Scene {
        Window("Quire PDF", id: "main") {
            ContentView()
                .environment(session)
                .environment(window)
                .frame(minWidth: 820, minHeight: 520)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDFs…") { window.isImporting = true }
                    .keyboardShortcut("o")
                Button("Merge & Save…") { window.isExportRequested = true }
                    .keyboardShortcut("e")
                    .disabled(session.pages.isEmpty)
                Divider()
                Button("Start Over…") { window.isConfirmingClear = true }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
                    .disabled(session.files.isEmpty)
            }
        }
    }
}
