import SwiftUI

struct ContentView: View {
    @Environment(Workspace.self) private var workspace

    var body: some View {
        @Bindable var workspace = workspace

        NavigationSplitView {
            FileListView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let file = workspace.selectedFile {
                PageGridView(file: file)
                    .id(file.id)
            } else {
                ContentUnavailableView {
                    Label("No PDF Selected", systemImage: "doc.richtext")
                } description: {
                    Text("Open PDF files, or drop them onto the sidebar.")
                } actions: {
                    Button("Open PDFs…") { workspace.isImporting = true }
                }
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
                    workspace.isExporting = true
                } label: {
                    Label("Merge & Export", systemImage: "square.and.arrow.up.on.square")
                }
                .help("Merge all files into one PDF and save it")
                .disabled(workspace.totalPageCount == 0)
            }
        }
        .fileImporter(isPresented: $workspace.isImporting,
                      allowedContentTypes: [.pdf],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): workspace.add(urls)
            case .failure(let error): workspace.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $workspace.isExporting) {
            ExportSheet()
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
