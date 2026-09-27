import SwiftUI

struct ContentView: View {
    @Environment(Workspace.self) private var workspace

    var body: some View {
        @Bindable var workspace = workspace

        NavigationSplitView {
            FileListView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if workspace.files.isEmpty {
                ContentUnavailableView {
                    Label("No PDFs", systemImage: "doc.richtext")
                } description: {
                    Text("Open PDF files, or drop them here or onto the sidebar.")
                } actions: {
                    Button("Open PDFs…") { workspace.isImporting = true }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    workspace.add(urls)
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
                    workspace.isImporting = true
                } label: {
                    Label("Open PDFs", systemImage: "plus")
                }
                .help("Add PDF files")

                Button {
                    workspace.isConfirmingClear = true
                } label: {
                    Label("Start Over", systemImage: "xmark.circle")
                }
                .help("Remove every file and start again (⇧⌘⌫)")
                .disabled(workspace.files.isEmpty)
            }
        }
        .confirmationDialog("Start over?", isPresented: $workspace.isConfirmingClear) {
            Button("Remove All Files", role: .destructive) {
                withAnimation { workspace.clear() }
            }
        } message: {
            Text("This removes \(workspace.files.count == 1 ? "the file" : "all \(workspace.files.count) files") and your page arrangement. The PDFs on disk are not changed.")
        }
        .fileImporter(isPresented: $workspace.isImporting,
                      allowedContentTypes: [.pdf],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): workspace.add(urls)
            case .failure(let error): workspace.errorMessage = error.localizedDescription
            }
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { workspace.errorMessage != nil },
                                    set: { if !$0 { workspace.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(workspace.errorMessage ?? "")
        }
    }
}
