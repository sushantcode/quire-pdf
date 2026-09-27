import Foundation
import Observation
import PDFKit
import SwiftUI

/// One page of a loaded PDF, with a stable identity so it can be dragged and
/// reordered, and a record of where it came from so pages from different files
/// can be told apart once they are interleaved.
struct PageRef: Identifiable, Hashable {
    let id = UUID()
    let page: PDFPage
    let fileID: PDFFile.ID
    /// 1-based position in the source file.
    let number: Int
}

/// A PDF the user has loaded. The source document is never modified; which of
/// its pages are merged, and where, is decided by `Workspace.pages`.
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

    static let tints: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .yellow, .brown]

    let id: UUID
    let name: String
    let originalByteCount: Int
    let document: PDFDocument
    /// Every page of the source, in source order.
    let pages: [PageRef]
    /// Which of `tints` marks this file's pages. Assigned when it is added, so
    /// a file keeps its colour when others are removed.
    var tintIndex = 0

    var tint: Color { Self.tints[tintIndex % Self.tints.count] }

    init(name: String, data: Data) throws {
        guard let document = PDFDocument(data: data) else { throw LoadError.unreadable(name) }
        guard !document.isLocked else { throw LoadError.locked(name) }
        let id = UUID()
        self.id = id
        self.name = name
        self.originalByteCount = data.count
        self.document = document
        self.pages = (0..<document.pageCount).compactMap { index in
            document.page(at: index).map { PageRef(page: $0, fileID: id, number: index + 1) }
        }
    }

    /// Loads a PDF from disk. The data is read eagerly so the security-scoped
    /// access granted by the open panel or a drop can be released straight away.
    static func load(from url: URL) throws -> PDFFile {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        return try PDFFile(name: url.deletingPathExtension().lastPathComponent, data: data)
    }
}

extension Array where Element: Identifiable {
    /// Moves the element with `id` into the position currently held by `target`,
    /// shifting the elements in between. Matches what a drop onto a grid cell means.
    mutating func move(_ id: Element.ID, onto target: Element.ID) {
        move([id], onto: target)
    }

    /// Moves the elements in `ids`, keeping their relative order, into the
    /// position held by `target`: after it when they come from before it, and
    /// before it otherwise, so a single element lands exactly where it was dropped.
    mutating func move(_ ids: Set<Element.ID>, onto target: Element.ID) {
        guard !ids.contains(target),
              let first = firstIndex(where: { ids.contains($0.id) }),
              let targetIndex = firstIndex(where: { $0.id == target })
        else { return }
        let forward = first < targetIndex
        let moving = filter { ids.contains($0.id) }
        removeAll { ids.contains($0.id) }
        let to = firstIndex(where: { $0.id == target })!
        insert(contentsOf: moving, at: forward ? to + 1 : to)
    }

    mutating func moveToStart(_ ids: Set<Element.ID>) {
        let moving = filter { ids.contains($0.id) }
        removeAll { ids.contains($0.id) }
        insert(contentsOf: moving, at: 0)
    }

    mutating func moveToEnd(_ ids: Set<Element.ID>) {
        let moving = filter { ids.contains($0.id) }
        removeAll { ids.contains($0.id) }
        append(contentsOf: moving)
    }
}
