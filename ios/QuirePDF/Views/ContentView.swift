import QuireKit
import SwiftUI

/// One window: the document and everything that acts on it. Each iPad window
/// gets its own, so two merges can be prepared side by side.
struct ContentView: View {
    @State private var session = MergeSession()
    @State private var screen = ScreenState()
    @AppStorage("compression") private var storedCompression = CompressionLevel.balanced.rawValue

    var body: some View {
        NavigationStack {
            Group {
                if session.files.isEmpty {
                    EmptyStateView()
                } else {
                    PageGridView()
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            if screen.isSelecting { SelectionBar() } else { MergeBar() }
                        }
                }
            }
            .navigationTitle("Quire PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .fileImporter(isPresented: $screen.isImporting, allowedContentTypes: [.pdf],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): screen.add(urls, to: session)
            case .failure(let error): screen.errorMessage = error.localizedDescription
            }
        }
        .onOpenURL { screen.add([$0], to: session) }
        .dropDestination(for: DroppedPDF.self) { items, _ in
            screen.add(items.map(\.url), to: session)
            return true
        }
        .sheet(isPresented: $screen.isShowingFiles) { FileListSheet() }
        .sheet(item: $screen.previewPage) { PagePreview(ref: $0) }
        .sheet(item: $screen.outcome, onDismiss: nil) { outcome in
            MergeResultSheet(outcome: outcome)
                .onDisappear { screen.discard(outcome) }
        }
        .confirmationDialog("Start over?", isPresented: $screen.isConfirmingClear, titleVisibility: .visible) {
            Button("Remove All Files", role: .destructive) {
                withAnimation { session.clear() }
                screen.isSelecting = false
            }
        } message: {
            Text("This removes every file and your page arrangement. The original PDFs are not changed.")
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { screen.errorMessage != nil },
                                    set: { if !$0 { screen.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(screen.errorMessage ?? "")
        }
        .environment(session)
        .environment(screen)
        .onAppear {
            session.compression = CompressionLevel(rawValue: storedCompression) ?? .balanced
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if session.files.isEmpty {
                if arguments.contains("-UITestSamples") { session.insert(SampleDocuments.make()) }
                if arguments.contains("-ScreenshotSamples") { session.insert(SampleDocuments.screenshotSet()) }
            }
            #endif
        }
        .onChange(of: session.compression) { storedCompression = $1.rawValue }
        .onChange(of: session.files.isEmpty) { if $1 { screen.isSelecting = false } }
        // Leaving Select mode drops the selection, so it never acts on pages out of sight.
        .onChange(of: screen.isSelecting) { if !$1 { session.selectedPageIDs.removeAll() } }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !session.files.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                if screen.isSelecting {
                    let allSelected = session.selectedPageIDs.count == session.pages.count
                    Button(allSelected ? "Deselect All" : "Select All") {
                        session.selectedPageIDs = allSelected ? [] : Set(session.pages.map(\.id))
                    }
                } else {
                    Button {
                        screen.isShowingFiles = true
                    } label: {
                        Label("Files", systemImage: "doc.on.doc")
                            .labelStyle(.titleAndIcon)
                    }
                    .accessibilityHint("Shows the files being merged, to reorder or remove them")
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(screen.isSelecting ? "Done" : "Select") {
                    withAnimation { screen.isSelecting.toggle() }
                }
                .fontWeight(screen.isSelecting ? .semibold : .regular)
                if !screen.isSelecting {
                    Menu {
                        Button {
                            screen.isImporting = true
                        } label: {
                            Label("Add PDFs", systemImage: "plus")
                        }
                        Button {
                            withAnimation { session.resetPages() }
                        } label: {
                            Label("Reset Pages", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(!session.isRearranged)
                        Divider()
                        Button(role: .destructive) {
                            screen.isConfirmingClear = true
                        } label: {
                            Label("Start Over", systemImage: "xmark.circle")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
    }
}
