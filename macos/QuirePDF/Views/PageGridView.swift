import PDFKit
import SwiftUI

/// Every page that will be merged, in output order, from all files at once.
/// Drag a page onto another to move it there, across files as freely as within one.
struct PageGridView: View {
    @Environment(Workspace.self) private var workspace
    /// Where a Shift-click range starts.
    @State private var anchor: PageRef.ID?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)]

    var body: some View {
        let files = Dictionary(uniqueKeysWithValues: workspace.files.map { ($0.id, $0) })

        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(Array(workspace.pages.enumerated()), id: \.element.id) { index, ref in
                        PageCell(ref: ref, position: index + 1, file: files[ref.fileID],
                                 isSelected: workspace.selectedPageIDs.contains(ref.id))
                            .id(ref.id)
                            .onTapGesture { select(ref.id) }
                            .draggable(ref.id.uuidString) {
                                DragPreview(page: ref.page, count: targets(for: ref.id).count)
                            }
                            .dropDestination(for: String.self) { items, _ in
                                guard let dragged = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                                withAnimation(.snappy) { workspace.movePages(targets(for: dragged), onto: ref.id) }
                                return true
                            }
                            .contextMenu { menu(for: ref.id) }
                    }
                }
                .padding(20)
            }
            // Picking a file in the sidebar selects its pages and brings the first into view.
            .onChange(of: workspace.selectedFileID) { _, id in
                guard let id else { return }
                let filePages = workspace.pages.filter { $0.fileID == id }
                workspace.selectedPageIDs = Set(filePages.map(\.id))
                anchor = filePages.first?.id
                if let first = filePages.first {
                    withAnimation { proxy.scrollTo(first.id, anchor: .top) }
                }
            }
        }
        .overlay {
            if workspace.pages.isEmpty {
                ContentUnavailableView {
                    Label("No Pages", systemImage: "doc")
                } description: {
                    Text("Every page has been deleted.")
                } actions: {
                    Button("Restore All Pages") { withAnimation { workspace.resetPages() } }
                }
            }
        }
        .onDeleteCommand { workspace.removePages(workspace.selectedPageIDs) }
        .navigationTitle("Merged PDF")
        .navigationSubtitle("\(workspace.pages.count.counted("page")) from \(workspace.files.count.counted("file")). Drag pages to reorder.")
        .toolbar {
            ToolbarItem {
                Button {
                    withAnimation { workspace.resetPages() }
                } label: {
                    Label("Reset Pages", systemImage: "arrow.uturn.backward")
                }
                .help("Restore every page of every file, in file order")
                .disabled(!workspace.isRearranged)
            }
        }
    }

    /// The pages an action on `id` applies to: the whole selection when `id`
    /// is part of it, otherwise just that page.
    private func targets(for id: PageRef.ID) -> Set<PageRef.ID> {
        workspace.selectedPageIDs.contains(id) ? workspace.selectedPageIDs : [id]
    }

    @ViewBuilder
    private func menu(for id: PageRef.ID) -> some View {
        let ids = targets(for: id)
        Button("Move to Start") { withAnimation(.snappy) { workspace.movePagesToStart(ids) } }
        Button("Move to End") { withAnimation(.snappy) { workspace.movePagesToEnd(ids) } }
        Divider()
        Button(ids.count > 1 ? "Delete \(ids.count) Pages" : "Delete Page", role: .destructive) {
            withAnimation { workspace.removePages(ids) }
        }
    }

    private func select(_ id: PageRef.ID) {
        let modifiers = NSEvent.modifierFlags
        let ids = workspace.pages.map(\.id)
        if modifiers.contains(.shift), let anchor,
           let from = ids.firstIndex(of: anchor), let to = ids.firstIndex(of: id) {
            workspace.selectedPageIDs = Set(ids[min(from, to)...max(from, to)])
        } else if modifiers.contains(.command) {
            if workspace.selectedPageIDs.contains(id) {
                workspace.selectedPageIDs.remove(id)
            } else {
                workspace.selectedPageIDs.insert(id)
            }
            anchor = id
        } else {
            workspace.selectedPageIDs = [id]
            anchor = id
        }
        // The selection is now pages, not a file.
        workspace.selectedFileID = nil
    }
}

private struct PageCell: View {
    let ref: PageRef
    let position: Int
    let file: PDFFile?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            PageImage(page: ref.page, maxPixelSize: 400)
                .frame(height: 200)
            Text("\(position)")
                .font(.callout.monospacedDigit().weight(.medium))
            if let file {
                SourceBadge(file: file, number: ref.number)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor.opacity(0.18) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2))
        .contentShape(Rectangle())
    }
}

/// Which file a page came from, and which page of it: the colour matches the file in the sidebar.
private struct SourceBadge: View {
    let file: PDFFile
    let number: Int

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(file.tint).frame(width: 7, height: 7)
            Text("\(file.name) · p\(number)")
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(file.tint.opacity(0.15)))
        .frame(maxWidth: 190)
        .help("Page \(number) of \(file.name)")
    }
}

private struct DragPreview: View {
    let page: PDFPage
    let count: Int

    var body: some View {
        PageImage(page: page, maxPixelSize: 200)
            .frame(width: 100, height: 130)
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("\(count)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                        .offset(x: 6, y: -6)
                }
            }
    }
}

/// A page thumbnail, rendered lazily and sized to the page's aspect ratio.
struct PageImage: View {
    let page: PDFPage
    let maxPixelSize: CGFloat
    @State private var image: NSImage?

    private var aspectRatio: CGFloat {
        let bounds = page.bounds(for: .cropBox)
        let quarterTurned = page.rotation % 180 != 0
        let width = quarterTurned ? bounds.height : bounds.width
        let height = quarterTurned ? bounds.width : bounds.height
        return height > 0 ? width / height : 1
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .background(.white)
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        .task(id: ObjectIdentifier(page)) {
            image = page.thumbnail(of: CGSize(width: maxPixelSize, height: maxPixelSize), for: .cropBox)
        }
    }
}

extension Int {
    /// "1 page", "3 pages".
    func counted(_ noun: String) -> String { "\(self) \(noun)\(self == 1 ? "" : "s")" }
}
