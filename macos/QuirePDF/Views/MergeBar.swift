import AppKit
import QuireKit
import SwiftUI

/// Pinned under the pages: what will be merged, how hard to compress it, and
/// the button that merges and saves, then says what it saved.
struct MergeBar: View {
    @Environment(MergeSession.self) private var session
    @Environment(WindowState.self) private var window
    @State private var isWorking = false
    @State private var saved: Saved?

    private struct Saved {
        let url: URL
        let size: Int
        let percentSaved: Int?
    }

    var body: some View {
        @Bindable var session = session
        let pageCount = session.pages.count

        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(pageCount.counted("page")) from \(session.files.count.counted("file"))")
                    .font(.headline)
                if let saved {
                    savedLine(saved)
                } else {
                    Text(session.compression.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(session.compression.detail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Compression", selection: $session.compression) {
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
        .onChange(of: window.isExportRequested) { _, requested in
            guard requested else { return }
            window.isExportRequested = false
            Task { await export() }
        }
        // A saved result describes the pages as they were; any edit makes it stale.
        .onChange(of: session.pages.map(\.id)) { saved = nil }
        .onChange(of: session.compression) { saved = nil }
    }

    private func savedLine(_ saved: Saved) -> some View {
        HStack(spacing: 8) {
            Label {
                Text("Saved \(saved.url.lastPathComponent) · \(saved.size.formatted(.byteCount(style: .file)))\(saved.percentSaved.map { ", \($0)% smaller" } ?? "")")
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

    private func export() async {
        guard !isWorking, !session.pages.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = session.files.count == 1 ? "\(session.files[0].name) (edited).pdf" : "Merged.pdf"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isWorking = true
        saved = nil
        defer { isWorking = false }
        do {
            let result = try await session.makeMergedPDF()
            try result.data.write(to: url, options: .atomic)
            saved = Saved(url: url, size: result.data.count, percentSaved: result.percentSaved)
        } catch {
            window.errorMessage = error.localizedDescription
        }
    }
}
