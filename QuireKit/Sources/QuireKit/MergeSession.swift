import Foundation
import Observation
import PDFKit
import UniformTypeIdentifiers

/// The PDFs a person has loaded, and the one sequence of pages they merge into.
/// Platform-neutral: window and screen state belongs to each app.
@Observable
public final class MergeSession {
    public private(set) var files: [PDFFile] = []
    /// Every page that will be merged, in output order. Pages from different
    /// files can be interleaved in any order.
    public private(set) var pages: [PageRef] = []
    public var selectedPageIDs: Set<PageRef.ID> = []
    public var selectedFileID: PDFFile.ID?
    public var compression: CompressionLevel = .balanced
    private var nextTint = 0

    public init() {}

    /// What loading some URLs produced: the files added, and a message for
    /// each one that could not be read.
    public struct ImportResult {
        public var added: [PDFFile] = []
        public var failures: [String] = []
    }

    public var totalByteCount: Int { files.reduce(0) { $0 + $1.originalByteCount } }

    public func file(_ id: PDFFile.ID) -> PDFFile? { files.first { $0.id == id } }

    /// How many of `file`'s pages are still in the merge.
    public func pageCount(of file: PDFFile) -> Int { pages.filter { $0.fileID == file.id }.count }

    /// Whether any of `file`'s pages were deleted or reordered among themselves.
    public func isModified(_ file: PDFFile) -> Bool {
        pages.filter { $0.fileID == file.id }.map(\.id) != file.pages.map(\.id)
    }

    /// Whether the pages differ from every page of every file, in file order.
    public var isRearranged: Bool { pages.map(\.id) != files.flatMap(\.pages).map(\.id) }

    /// Loads PDFs from `urls` and inserts them at `index` (the end by default).
    /// Non-PDF URLs are ignored.
    @discardableResult
    public func add(_ urls: [URL], at index: Int? = nil) -> ImportResult {
        var result = ImportResult()
        for url in urls where Self.isPDF(url) {
            do {
                result.added.append(try PDFFile.load(from: url))
            } catch {
                result.failures.append(error.localizedDescription)
            }
        }
        insert(result.added, at: index)
        return result
    }

    /// Inserts `newFiles` at `index` in the file list. Their pages go where the
    /// files now sit: before the first page of any file that follows them, or
    /// at the end.
    public func insert(_ newFiles: [PDFFile], at index: Int? = nil) {
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
    public func moveFiles(from source: IndexSet, to destination: Int) {
        files.move(fromOffsets: source, toOffset: destination)
        let rank = Dictionary(uniqueKeysWithValues: files.enumerated().map { ($1.id, $0) })
        pages = pages.enumerated()
            .sorted { (rank[$0.element.fileID] ?? 0, $0.offset) < (rank[$1.element.fileID] ?? 0, $1.offset) }
            .map(\.element)
    }

    public func remove(_ ids: Set<PDFFile.ID>) {
        files.removeAll { ids.contains($0.id) }
        pages.removeAll { ids.contains($0.fileID) }
        selectedPageIDs = selectedPageIDs.filter { id in pages.contains { $0.id == id } }
        if let selectedFileID, ids.contains(selectedFileID) { self.selectedFileID = nil }
    }

    public func movePages(_ ids: Set<PageRef.ID>, onto target: PageRef.ID) { pages.move(ids, onto: target) }
    public func movePagesToStart(_ ids: Set<PageRef.ID>) { pages.moveToStart(ids) }
    public func movePagesToEnd(_ ids: Set<PageRef.ID>) { pages.moveToEnd(ids) }

    /// Moves one page a single place earlier or later, for keyboard and
    /// VoiceOver users who cannot drag.
    public func movePage(_ id: PageRef.ID, by offset: Int) {
        guard let from = pages.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard pages.indices.contains(to) else { return }
        pages.swapAt(from, to)
    }

    public func removePages(_ ids: Set<PageRef.ID>) {
        pages.removeAll { ids.contains($0.id) }
        selectedPageIDs.subtract(ids)
    }

    /// Restores every page of every file, in file order.
    public func resetPages() {
        pages = files.flatMap(\.pages)
        selectedPageIDs.removeAll()
    }

    /// Removes every file and page. Files on disk are never touched, so this
    /// only discards the arrangement.
    public func clear() {
        files.removeAll()
        pages.removeAll()
        selectedPageIDs.removeAll()
        selectedFileID = nil
        nextTint = 0
    }

    /// The pages to merge, in output order.
    public var pagesForMerge: [PDFPage] { pages.map(\.page) }

    /// Merges the pages and compresses the result at `compression`. The
    /// compression runs off the main actor, since it can take seconds on a
    /// large document.
    public func makeMergedPDF() async throws -> MergeResult {
        let merged = try PDFComposer.merge(pagesForMerge)
        let level = compression
        let output = try await Task.detached(priority: .userInitiated) {
            try PDFCompressor.compress(merged, level: level)
        }.value
        return MergeResult(data: output, uncompressedSize: merged.count, pageCount: pages.count)
    }

    public static func isPDF(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) ?? false
    }
}

/// A finished merge: the bytes to save, and how much compression saved.
public struct MergeResult: Sendable {
    public let data: Data
    public let uncompressedSize: Int
    public let pageCount: Int

    public init(data: Data, uncompressedSize: Int, pageCount: Int) {
        self.data = data
        self.uncompressedSize = uncompressedSize
        self.pageCount = pageCount
    }

    /// Whole percent by which compression shrank the file, or nil if it did not.
    public var percentSaved: Int? {
        guard uncompressedSize > 0, data.count < uncompressedSize else { return nil }
        let percent = Int((1 - Double(data.count) / Double(uncompressedSize)) * 100)
        return percent > 0 ? percent : nil
    }
}

extension Int {
    /// "1 page", "3 pages".
    public func counted(_ noun: String) -> String { "\(self) \(noun)\(self == 1 ? "" : "s")" }
}
