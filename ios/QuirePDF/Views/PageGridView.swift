import QuireKit
import SwiftUI

/// Every page that will be merged, in output order, from all files at once.
/// Touch and hold a page, then drag it onto another to move it there, across
/// files as freely as within one. In Select mode, taps build a selection that
/// the selection bar acts on, and dragging a selected page moves all of them.
struct PageGridView: View {
    @Environment(MergeSession.self) private var session
    @Environment(ScreenState.self) private var screen
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var thumbnailSize: CGFloat { sizeClass == .compact ? 128 : 180 }

    var body: some View {
        let files = Dictionary(uniqueKeysWithValues: session.files.map { ($0.id, $0) })
        let columns = [GridItem(.adaptive(minimum: thumbnailSize * 0.8, maximum: thumbnailSize * 1.2), spacing: 12)]

        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(session.pages.enumerated()), id: \.element.id) { index, ref in
                        let file = files[ref.fileID]
                        PageCell(ref: ref, position: index + 1, file: file, thumbnailSize: thumbnailSize,
                                 isSelecting: screen.isSelecting,
                                 isSelected: session.selectedPageIDs.contains(ref.id))
                            .id(ref.id)
                            .onTapGesture { tap(ref) }
                            .draggable(ref.id.uuidString) {
                                DragPreview(ref: ref, count: targets(for: ref.id).count)
                            }
                            .dropDestination(for: String.self) { items, _ in
                                guard let dragged = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                                withAnimation(.snappy) { session.movePages(targets(for: dragged), onto: ref.id) }
                                return true
                            }
                            .contextMenu { menu(for: ref) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(accessibilityLabel(ref, position: index + 1, file: file))
                            .accessibilityHint(screen.isSelecting ? "Double-tap to select or deselect" : "Double-tap to preview")
                            .accessibilityAddTraits(session.selectedPageIDs.contains(ref.id) ? [.isButton, .isSelected] : .isButton)
                            .accessibilityIdentifier("page-\(index + 1)")
                            .accessibilityActions { accessibilityActions(for: ref.id) }
                    }
                }
                .padding(16)
            }
            // Picking a file in the Files sheet selects its pages and brings the first into view.
            .onChange(of: session.selectedFileID) { _, id in
                guard let id else { return }
                let filePages = session.pages.filter { $0.fileID == id }
                session.selectedPageIDs = Set(filePages.map(\.id))
                if let first = filePages.first {
                    withAnimation { proxy.scrollTo(first.id, anchor: .top) }
                }
                session.selectedFileID = nil
            }
        }
        .overlay {
            if session.pages.isEmpty {
                ContentUnavailableView {
                    Label("No Pages", systemImage: "doc")
                } description: {
                    Text("Every page has been deleted.")
                } actions: {
                    Button("Restore All Pages") { withAnimation { session.resetPages() } }
                }
            }
        }
    }

    private func tap(_ ref: PageRef) {
        guard screen.isSelecting else {
            screen.previewPage = ref
            return
        }
        if session.selectedPageIDs.contains(ref.id) {
            session.selectedPageIDs.remove(ref.id)
        } else {
            session.selectedPageIDs.insert(ref.id)
        }
    }

    /// The pages an action on `id` applies to: the whole selection when `id`
    /// is part of it, otherwise just that page.
    private func targets(for id: PageRef.ID) -> Set<PageRef.ID> {
        session.selectedPageIDs.contains(id) ? session.selectedPageIDs : [id]
    }

    @ViewBuilder
    private func menu(for ref: PageRef) -> some View {
        let ids = targets(for: ref.id)
        if ids.count == 1 {
            Button {
                screen.previewPage = ref
            } label: {
                Label("Preview", systemImage: "eye")
            }
        }
        Button {
            withAnimation(.snappy) { session.movePagesToStart(ids) }
        } label: {
            Label("Move to Start", systemImage: "arrow.up.to.line")
        }
        Button {
            withAnimation(.snappy) { session.movePagesToEnd(ids) }
        } label: {
            Label("Move to End", systemImage: "arrow.down.to.line")
        }
        Divider()
        Button(role: .destructive) {
            withAnimation { session.removePages(ids) }
        } label: {
            Label(ids.count > 1 ? "Delete \(ids.count) Pages" : "Delete Page", systemImage: "trash")
        }
    }

    private func accessibilityLabel(_ ref: PageRef, position: Int, file: PDFFile?) -> Text {
        guard let file else { return Text("Page \(position)") }
        return Text("Page \(position), from \(file.name), page \(ref.number)")
    }

    /// Dragging is hard with VoiceOver, so every move it allows is also an action.
    @ViewBuilder
    private func accessibilityActions(for id: PageRef.ID) -> some View {
        Button("Move Earlier") { session.movePage(id, by: -1) }
        Button("Move Later") { session.movePage(id, by: 1) }
        Button("Move to Start") { session.movePagesToStart([id]) }
        Button("Move to End") { session.movePagesToEnd([id]) }
        Button("Delete Page") { session.removePages([id]) }
    }
}

private struct PageCell: View {
    let ref: PageRef
    let position: Int
    let file: PDFFile?
    let thumbnailSize: CGFloat
    let isSelecting: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            PageThumbnail(ref: ref, size: thumbnailSize)
                .frame(height: thumbnailSize)
                .overlay(alignment: .bottomTrailing) {
                    if isSelecting {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(isSelected ? Color.white : Color.secondary,
                                             isSelected ? Color.accentColor : Color(.systemBackground).opacity(0.8))
                            .padding(6)
                    }
                }
            Text("\(position)")
                .font(.subheadline.monospacedDigit().weight(.medium))
            if let file {
                SourceBadge(file: file, number: ref.number)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.accentColor.opacity(0.15) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2))
        .contentShape(.rect(cornerRadius: 10))
        .contentShape(.dragPreview, .rect(cornerRadius: 10))
    }
}

/// Which file a page came from, and which page of it: the colour matches the
/// file's stripe in the Files sheet.
struct SourceBadge: View {
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
    }
}

private struct DragPreview: View {
    let ref: PageRef
    let count: Int

    var body: some View {
        PageThumbnail(ref: ref, size: 110)
            .frame(width: 90, height: 110)
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("\(count)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                        .offset(x: 8, y: -8)
                }
            }
    }
}
