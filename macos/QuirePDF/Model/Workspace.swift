import Foundation
import Observation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// The set of PDFs open in the window, in the order they will be merged.
@Observable
final class Workspace {
    var files: [PDFFile] = []
    var selectedFileID: PDFFile.ID?
    var isImporting = false
    var isExporting = false
    var errorMessage: String?

    var selectedFile: PDFFile? { files.first { $0.id == selectedFileID } }
    var totalPageCount: Int { files.reduce(0) { $0 + $1.pages.count } }
    var totalByteCount: Int { files.reduce(0) { $0 + $1.originalByteCount } }

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
        let insertAt = min(index ?? files.count, files.count)
        files.insert(contentsOf: loaded, at: insertAt)
        if selectedFileID == nil { selectedFileID = loaded.first?.id }
        if !failures.isEmpty { errorMessage = failures.joined(separator: "\n") }
    }

    func moveFiles(from source: IndexSet, to destination: Int) {
        files.move(fromOffsets: source, toOffset: destination)
    }

    func remove(_ ids: Set<PDFFile.ID>) {
        files.removeAll { ids.contains($0.id) }
        if let selectedFileID, ids.contains(selectedFileID) {
            self.selectedFileID = files.first?.id
        }
    }

    /// Every remaining page, in file order and then page order.
    var pagesForMerge: [PDFPage] {
        files.flatMap { $0.pages.map(\.page) }
    }

    static func isPDF(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) ?? false
    }
}
