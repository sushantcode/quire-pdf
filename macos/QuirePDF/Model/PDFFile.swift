import Foundation
import Observation
import PDFKit

/// One page of a loaded PDF, with a stable identity so it can be dragged and reordered.
struct PageRef: Identifiable, Hashable {
    let id = UUID()
    let page: PDFPage
}

/// A PDF the user has loaded. Edits (reorder, delete) only change `pages`;
/// the source document is left untouched until export.
@Observable
final class PDFFile: Identifiable {
    enum LoadError: LocalizedError {
        case unreadable(String)
        case locked(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let name): "“\(name)” is not a readable PDF."
            case .locked(let name): "“\(name)” is password protected and can’t be edited."
            }
        }
    }

    let id = UUID()
    let name: String
    let originalByteCount: Int
    let document: PDFDocument
    private let originalPages: [PageRef]
    var pages: [PageRef]

    init(name: String, data: Data) throws {
        guard let document = PDFDocument(data: data) else { throw LoadError.unreadable(name) }
        guard !document.isLocked else { throw LoadError.locked(name) }
        self.name = name
        self.originalByteCount = data.count
        self.document = document
        let pages = (0..<document.pageCount).compactMap { document.page(at: $0) }.map { PageRef(page: $0) }
        self.originalPages = pages
        self.pages = pages
    }

    /// Loads a PDF from disk. The data is read eagerly so the security-scoped
    /// access granted by the open panel or a drop can be released straight away.
    static func load(from url: URL) throws -> PDFFile {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        return try PDFFile(name: url.deletingPathExtension().lastPathComponent, data: data)
    }

    var isModified: Bool { pages.map(\.id) != originalPages.map(\.id) }

    func movePage(_ id: PageRef.ID, onto target: PageRef.ID) {
        pages.move(id, onto: target)
    }

    func removePages(_ ids: Set<PageRef.ID>) {
        pages.removeAll { ids.contains($0.id) }
    }

    func resetPages() {
        pages = originalPages
    }
}

extension Array where Element: Identifiable {
    /// Moves the element with `id` into the position currently held by `target`,
    /// shifting the elements in between. Matches what a drop onto a grid cell means.
    mutating func move(_ id: Element.ID, onto target: Element.ID) {
        guard id != target,
              let from = firstIndex(where: { $0.id == id }),
              let to = firstIndex(where: { $0.id == target })
        else { return }
        let element = remove(at: from)
        insert(element, at: to)
    }
}
