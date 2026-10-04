import QuireKit
import SwiftUI

/// The files being merged. Reorder them to regroup the pages file by file,
/// swipe to remove one, or tap one to select its pages.
struct FileListSheet: View {
    @Environment(MergeSession.self) private var session
    @Environment(ScreenState.self) private var screen
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(session.files.enumerated()), id: \.element.id) { index, file in
                        Button {
                            screen.isSelecting = true
                            session.selectedFileID = file.id
                            dismiss()
                        } label: {
                            FileRow(file: file, position: index + 1,
                                    pagesInMerge: session.pageCount(of: file),
                                    isModified: session.isModified(file))
                        }
                        .tint(.primary)
                        .accessibilityHint("Selects this file's pages")
                    }
                    .onMove { session.moveFiles(from: $0, to: $1) }
                    .onDelete { offsets in
                        withAnimation { session.remove(Set(offsets.map { session.files[$0].id })) }
                    }
                } footer: {
                    Text("Drag to change the order of files. This regroups their pages file by file, so pages you moved between files go back to their own file.")
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        screen.isImporting = true
                    } label: {
                        Label("Add PDFs", systemImage: "plus")
                    }
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .overlay {
                if session.files.isEmpty {
                    ContentUnavailableView("No Files", systemImage: "doc")
                }
            }
        }
        .presentationDetents([.medium, .large])
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
            : String(localized: "\(pagesInMerge) of \(file.pages.count) pages")
        let size = file.originalByteCount.formatted(.byteCount(style: .file))
        return isModified ? "\(pages) · \(size) · \(String(localized: "edited"))" : "\(pages) · \(size)"
    }

    var body: some View {
        HStack(spacing: 12) {
            // The same colour marks this file's pages in the grid.
            RoundedRectangle(cornerRadius: 1.5)
                .fill(file.tint)
                .frame(width: 4, height: 40)
            if let first = file.pages.first {
                PageThumbnail(ref: first, size: 44)
                    .frame(width: 34, height: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("\(position)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("File \(position)")
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
