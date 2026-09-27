import PDFKit
import SwiftUI

/// Thumbnails of one file's pages. Drag a page onto another to move it there.
struct PageGridView: View {
    @Bindable var file: PDFFile
    @State private var selection: Set<PageRef.ID> = []

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Array(file.pages.enumerated()), id: \.element.id) { index, ref in
                    PageCell(page: ref.page, number: index + 1, isSelected: selection.contains(ref.id))
                        .onTapGesture { toggleSelection(ref.id) }
                        .draggable(ref.id.uuidString) {
                            PageImage(page: ref.page, maxPixelSize: 200).frame(width: 100, height: 130)
                        }
                        .dropDestination(for: String.self) { items, _ in
                            guard let dragged = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                            withAnimation(.snappy) { file.movePage(dragged, onto: ref.id) }
                            return true
                        }
                        .contextMenu {
                            Button("Delete Page", role: .destructive) {
                                file.removePages(selection.contains(ref.id) ? selection : [ref.id])
                                selection.removeAll()
                            }
                        }
                }
            }
            .padding(20)
        }
        .onDeleteCommand {
            file.removePages(selection)
            selection.removeAll()
        }
        .navigationTitle(file.name)
        .navigationSubtitle("\(file.pages.count) of \(file.document.pageCount) pages — drag to reorder")
        .toolbar {
            ToolbarItem {
                Button {
                    withAnimation { file.resetPages() }
                    selection.removeAll()
                } label: {
                    Label("Reset Pages", systemImage: "arrow.uturn.backward")
                }
                .help("Restore the original page order and deleted pages")
                .disabled(!file.isModified)
            }
        }
    }

    private func toggleSelection(_ id: PageRef.ID) {
        if NSEvent.modifierFlags.contains(.command) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        } else {
            selection = [id]
        }
    }
}

private struct PageCell: View {
    let page: PDFPage
    let number: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            PageImage(page: page, maxPixelSize: 400)
                .frame(height: 200)
            Text("\(number)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor.opacity(0.18) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2))
        .contentShape(Rectangle())
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
