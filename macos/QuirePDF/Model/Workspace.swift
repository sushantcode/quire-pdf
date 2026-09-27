import Foundation
import Observation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// The PDFs open in the window, and the one sequence of pages they merge into.
@Observable
final class Workspace {
    var files: [PDFFile] = []
    /// Every page that will be merged, in output order. Pages from different
    /// files can be interleaved in any order.
    var pages: [PageRef] = []
    var selectedPageIDs: Set<PageRef.ID> = []
    var selectedFileID: PDFFile.ID?
    var compression: CompressionLevel = .balanced
    var isImporting = false
    /// Set to ask before `clear()`; the window shows the confirmation.
    var isConfirmingClear = false
    /// Set by the menu command; the merge bar runs the export and clears it.
    var isExportRequested = false
    var errorMessage: String?
    private var nextTint = 0

    var totalByteCount: Int { files.reduce(0) { $0 + $1.originalByteCount } }

    func file(_ id: PDFFile.ID) -> PDFFile? { files.first { $0.id == id } }

    /// How many of `file`'s pages are still in the merge.
    func pageCount(of file: PDFFile) -> Int { pages.filter { $0.fileID == file.id }.count }

    /// Whether any of `file`'s pages were deleted or reordered among themselves.
    func isModified(_ file: PDFFile) -> Bool {
        pages.filter { $0.fileID == file.id }.map(\.id) != file.pages.map(\.id)
    }

    /// Whether the pages differ from every page of every file, in file order.
    var isRearranged: Bool { pages.map(\.id) != files.flatMap(\.pages).map(\.id) }

    /// Loads PDFs from `urls` and inserts them at `index` (the end by default).
    /// Non-PDF URLs are ignored; failures are collected into `errorMessage`.
    func add(_ urls: [URL], at index: Int? = nil) {
        var loaded: [PDFFile] = []
        var failures: [String] = []
        for url in urls where Self.isPDF(url) {
            do {
                loaded.append(try PDFFile.load(from: url))
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        insert(loaded, at: index)
        if !failures.isEmpty { errorMessage = failures.joined(separator: "\n") }
    }

    /// Inserts `newFiles` at `index` in the file list. Their pages go where the
    /// files now sit: before the first page of any file that follows them, or
    /// at the end.
    func insert(_ newFiles: [PDFFile], at index: Int? = nil) {
        guard !newFiles.isEmpty else { return }
        let insertAt = min(index ?? files.count, files.count)
        for file in newFiles {
            file.tintIndex = nextTint
            nextTint += 1
        }
        let following = Set(files[insertAt...].map(\.id))
        let pageIndex = pages.firstIndex { following.contains($0.fileID) } ?? pages.count
        files.insert(contentsOf: newFiles, at: insertAt)
        pages.insert(contentsOf: newFiles.flatMap(\.pages), at: pageIndex)
    }

    /// Reorders the file list and regroups the pages to match: each file's
    /// pages become one run, in file order, keeping their order within the file.
    /// Pages moved between files are gathered back to their own file.
    func moveFiles(from source: IndexSet, to destination: Int) {
        files.move(fromOffsets: source, toOffset: destination)
        let rank = Dictionary(uniqueKeysWithValues: files.enumerated().map { ($1.id, $0) })
        pages = pages.enumerated()
            .sorted { (rank[$0.element.fileID] ?? 0, $0.offset) < (rank[$1.element.fileID] ?? 0, $1.offset) }
            .map(\.element)
    }

    func remove(_ ids: Set<PDFFile.ID>) {
        files.removeAll { ids.contains($0.id) }
        pages.removeAll { ids.contains($0.fileID) }
        selectedPageIDs = selectedPageIDs.filter { id in pages.contains { $0.id == id } }
        if let selectedFileID, ids.contains(selectedFileID) { self.selectedFileID = nil }
    }

    func movePages(_ ids: Set<PageRef.ID>, onto target: PageRef.ID) { pages.move(ids, onto: target) }
    func movePagesToStart(_ ids: Set<PageRef.ID>) { pages.moveToStart(ids) }
    func movePagesToEnd(_ ids: Set<PageRef.ID>) { pages.moveToEnd(ids) }

    func removePages(_ ids: Set<PageRef.ID>) {
        pages.removeAll { ids.contains($0.id) }
        selectedPageIDs.subtract(ids)
    }

    /// Restores every page of every file, in file order.
    func resetPages() {
        pages = files.flatMap(\.pages)
        selectedPageIDs.removeAll()
    }

    /// Removes every file and page, back to an empty window. Files on disk are
    /// never touched, so this only discards the arrangement.
    func clear() {
        files.removeAll()
        pages.removeAll()
        selectedPageIDs.removeAll()
        selectedFileID = nil
        nextTint = 0
    }

    /// The pages to merge, in output order.
    var pagesForMerge: [PDFPage] { pages.map(\.page) }

    static func isPDF(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) ?? false
    }
}
