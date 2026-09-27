import AppKit
import SwiftUI

/// Confirms merge order, picks a compression level, then writes the merged PDF.
struct ExportSheet: View {
    @Environment(Workspace.self) private var workspace
    @Environment(\.dismiss) private var dismiss
    @State private var level: CompressionLevel = .balanced
    @State private var isWorking = false
    @State private var savedSummary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Merge & Export").font(.title2.bold())

            GroupBox("Files, in merge order") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(workspace.files.enumerated()), id: \.element.id) { index, file in
                            HStack {
                                Text("\(index + 1). \(file.name)").lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Text("\(file.pages.count) pages").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }
                .frame(maxHeight: 140)
            }

            Picker("Compression", selection: $level) {
                ForEach(CompressionLevel.allCases) { level in
                    VStack(alignment: .leading) {
                        Text(level.title)
                        Text(level.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(level)
                }
            }
            .pickerStyle(.radioGroup)

            if let savedSummary {
                Label(savedSummary, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            HStack {
                if isWorking { ProgressView().controlSize(.small) }
                Spacer()
                Button(savedSummary == nil ? "Cancel" : "Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Merge & Save…") { Task { await export() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isWorking || workspace.totalPageCount == 0)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func export() async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = workspace.files.count == 1 ? "\(workspace.files[0].name) (edited).pdf" : "Merged.pdf"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isWorking = true
        savedSummary = nil
        defer { isWorking = false }
        do {
            let merged = try PDFComposer.merge(workspace.pagesForMerge)
            let level = level
            let output = try await Task.detached(priority: .userInitiated) {
                try PDFCompressor.compress(merged, level: level)
            }.value
            try output.write(to: url, options: .atomic)
            savedSummary = "Saved \(url.lastPathComponent) — \(output.count.formatted(.byteCount(style: .file))) (merged size \(merged.count.formatted(.byteCount(style: .file))))"
        } catch {
            workspace.errorMessage = error.localizedDescription
        }
    }
}
