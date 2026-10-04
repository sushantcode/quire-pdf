import QuireKit
import SwiftUI

struct ContentView: View {
    @Environment(MergeSession.self) private var session
    @Environment(WindowState.self) private var window

    var body: some View {
        @Bindable var window = window

        NavigationSplitView {
            FileListView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if session.files.isEmpty {
                ContentUnavailableView {
                    Label("No PDFs", systemImage: "doc.richtext")
                } description: {
                    Text("Open PDF files, or drop them here or onto the sidebar.")
                } actions: {
                    Button("Open PDFs…") { window.isImporting = true }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    window.add(urls, to: session)
                    return true
                }
            } else {
                PageGridView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { MergeBar() }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    window.isImporting = true
                } label: {
                    Label("Open PDFs", systemImage: "plus")
                }
                .help("Add PDF files")

                Button {
                    window.isConfirmingClear = true
                } label: {
                    Label("Start Over", systemImage: "xmark.circle")
                }
                .help("Remove every file and start again (⇧⌘⌫)")
                .disabled(session.files.isEmpty)
            }
        }
        .confirmationDialog("Start over?", isPresented: $window.isConfirmingClear) {
            Button("Remove All Files", role: .destructive) {
                withAnimation { session.clear() }
            }
        } message: {
            Text("This removes \(session.files.count == 1 ? "the file" : "all \(session.files.count) files") and your page arrangement. The PDFs on disk are not changed.")
        }
        .fileImporter(isPresented: $window.isImporting,
                      allowedContentTypes: [.pdf],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): window.add(urls, to: session)
            case .failure(let error): window.errorMessage = error.localizedDescription
            }
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { window.errorMessage != nil },
                                    set: { if !$0 { window.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(window.errorMessage ?? "")
        }
    }
}
