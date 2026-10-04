import QuireKit
import SwiftUI

/// Sidebar listing the loaded PDFs. Selecting one selects its pages. Dragging
/// rows regroups the pages file by file; drop PDFs from Finder to add them at
/// the drop position.
struct FileListView: View {
    @Environment(MergeSession.self) private var session
    @Environment(WindowState.self) private var window

    var body: some View {
        @Bindable var session = session

        List(selection: $session.selectedFileID) {
            Section("Files") {
                ForEach(Array(session.files.enumerated()), id: \.element.id) { index, file in
                    FileRow(file: file, position: index + 1,
                            pagesInMerge: session.pageCount(of: file),
                            isModified: session.isModified(file))
                        .tag(file.id)
                        .contextMenu {
                            Button("Remove", role: .destructive) { session.remove([file.id]) }
                        }
                }
                .onMove { session.moveFiles(from: $0, to: $1) }
                .dropDestination(for: URL.self) { urls, index in
                    window.add(urls, to: session, at: index)
                }
            }
        }
        .overlay {
            if session.files.isEmpty {
                Text("Drop PDFs here")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .dropDestination(for: URL.self) { urls, _ in
                        window.add(urls, to: session)
                        return true
                    }
            }
        }
        .onDeleteCommand {
            if let id = session.selectedFileID { session.remove([id]) }
        }
        .safeAreaInset(edge: .bottom) {
            if !session.files.isEmpty {
                Text("\(session.files.count.counted("file")) · \(session.totalByteCount.formatted(.byteCount(style: .file)))")
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
    let pagesInMerge: Int
    let isModified: Bool

    private var detail: String {
        let pages = pagesInMerge == file.pages.count
            ? file.pages.count.counted("page")
            : "\(pagesInMerge) of \(file.pages.count) pages"
        return "\(pages) · \(file.originalByteCount.formatted(.byteCount(style: .file)))\(isModified ? " · edited" : "")"
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(position)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
            // The same colour marks this file's pages in the grid.
            RoundedRectangle(cornerRadius: 1.5)
                .fill(file.tint)
                .frame(width: 3, height: 32)
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
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
