import SwiftUI

@main
struct QuirePDFApp: App {
    @State private var workspace = Workspace()

    var body: some Scene {
        Window("Quire PDF", id: "main") {
            ContentView()
                .environment(workspace)
                .frame(minWidth: 820, minHeight: 520)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDFs…") { workspace.isImporting = true }
                    .keyboardShortcut("o")
                Button("Merge & Save…") { workspace.isExportRequested = true }
                    .keyboardShortcut("e")
                    .disabled(workspace.pages.isEmpty)
                Divider()
                Button("Start Over…") { workspace.isConfirmingClear = true }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
                    .disabled(workspace.files.isEmpty)
            }
        }
    }
}
