import SwiftUI

/// Sidebar listing the loaded PDFs in merge order. Drag rows to reorder;
/// drop PDFs from Finder to add them at the drop position.
struct FileListView: View {
    @Environment(Workspace.self) private var workspace

    var body: some View {
        @Bindable var workspace = workspace

        List(selection: $workspace.selectedFileID) {
            Section("Merge order") {
                ForEach(Array(workspace.files.enumerated()), id: \.element.id) { index, file in
                    FileRow(file: file, position: index + 1)
                        .tag(file.id)
                        .contextMenu {
                            Button("Remove", role: .destructive) { workspace.remove([file.id]) }
                        }
                }
                .onMove { workspace.moveFiles(from: $0, to: $1) }
                .dropDestination(for: URL.self) { urls, index in
                    workspace.add(urls, at: index)
                }
            }
        }
        .overlay {
            if workspace.files.isEmpty {
                Text("Drop PDFs here")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .dropDestination(for: URL.self) { urls, _ in
                        workspace.add(urls)
                        return true
                    }
            }
        }
        .onDeleteCommand {
            if let id = workspace.selectedFileID { workspace.remove([id]) }
        }
        .safeAreaInset(edge: .bottom) {
            if !workspace.files.isEmpty {
                Text("\(workspace.files.count) files · \(workspace.totalPageCount) pages · \(workspace.totalByteCount.formatted(.byteCount(style: .file)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
    }
}

private struct FileRow: View {
    let file: PDFFile
    let position: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\(position)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
            if let first = file.pages.first {
                PageImage(page: first.page, maxPixelSize: 80)
                    .frame(width: 28, height: 36)
            } else {
                Image(systemName: "doc")
                    .frame(width: 28, height: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(file.pages.count) pages · \(file.originalByteCount.formatted(.byteCount(style: .file)))\(file.isModified ? " · edited" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
