import AppKit
import SwiftUI

/// Pinned under the pages: what will be merged, how hard to compress it, and
/// the button that merges and saves, then says what it saved.
struct MergeBar: View {
    @Environment(Workspace.self) private var workspace
    @State private var isWorking = false
    @State private var saved: Saved?

    private struct Saved {
        let url: URL
        let size: Int
        let uncompressedSize: Int
    }

    var body: some View {
        @Bindable var workspace = workspace
        let pageCount = workspace.pages.count

        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(pageCount.counted("page")) from \(workspace.files.count.counted("file"))")
                    .font(.headline)
                if let saved {
                    savedLine(saved)
                } else {
                    Text(workspace.compression.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(workspace.compression.detail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Compression", selection: $workspace.compression) {
                ForEach(CompressionLevel.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .disabled(isWorking)

            Button {
                Task { await export() }
            } label: {
                HStack(spacing: 6) {
                    if isWorking {
                        ProgressView().controlSize(.small)
                        Text("Merging…")
                    } else {
                        Image(systemName: "arrow.triangle.merge")
                        Text("Merge \(pageCount.counted("Page"))…")
                    }
                }
                .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isWorking || pageCount == 0)
            .help("Merge every page shown, in this order, into one PDF (⌘E)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .onChange(of: workspace.isExportRequested) { _, requested in
            guard requested else { return }
            workspace.isExportRequested = false
            Task { await export() }
        }
        // A saved result describes the pages as they were; any edit makes it stale.
        .onChange(of: workspace.pages.map(\.id)) { saved = nil }
        .onChange(of: workspace.compression) { saved = nil }
    }

    private func savedLine(_ saved: Saved) -> some View {
        HStack(spacing: 8) {
            Label {
                Text("Saved \(saved.url.lastPathComponent) · \(saved.size.formatted(.byteCount(style: .file)))\(reduction(saved))")
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([saved.url]) }
                .buttonStyle(.link)
        }
        .font(.caption)
    }

    private func reduction(_ saved: Saved) -> String {
        guard saved.size < saved.uncompressedSize, saved.uncompressedSize > 0 else { return "" }
        let percent = Int((1 - Double(saved.size) / Double(saved.uncompressedSize)) * 100)
        return percent > 0 ? ", \(percent)% smaller" : ""
    }

    private func export() async {
        guard !isWorking, !workspace.pages.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = workspace.files.count == 1 ? "\(workspace.files[0].name) (edited).pdf" : "Merged.pdf"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isWorking = true
        saved = nil
        defer { isWorking = false }
        do {
            let merged = try PDFComposer.merge(workspace.pagesForMerge)
            let level = workspace.compression
            let output = try await Task.detached(priority: .userInitiated) {
                try PDFCompressor.compress(merged, level: level)
            }.value
            try output.write(to: url, options: .atomic)
            saved = Saved(url: url, size: output.count, uncompressedSize: merged.count)
        } catch {
            workspace.errorMessage = error.localizedDescription
        }
    }
}
