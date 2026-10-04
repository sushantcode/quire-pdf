import Foundation
import Observation
import QuireKit

/// What one window shows besides the document: sheets, modes, the merge in
/// progress, and the last problem to report. The document itself is the
/// shared `MergeSession`. On iPad each window has its own pair.
@Observable
final class ScreenState {
    var isImporting = false
    var isShowingFiles = false
    var isSelecting = false
    var isConfirmingClear = false
    var previewPage: PageRef?
    var isMerging = false
    var outcome: MergeOutcome?
    var errorMessage: String?

    /// Adds `urls` to `session`, reports any that could not be read, and
    /// deletes copies the system or a drop made for us: the data is already
    /// in memory, and nobody else will clean them up.
    func add(_ urls: [URL], to session: MergeSession) {
        let result = session.add(urls)
        for url in urls where Self.isDisposableCopy(url) {
            try? FileManager.default.removeItem(at: url)
        }
        if !result.failures.isEmpty {
            errorMessage = result.failures.joined(separator: "\n")
        } else if result.added.isEmpty && !urls.isEmpty {
            errorMessage = String(localized: "Only PDF files can be added.")
        }
    }

    /// Merges and compresses `session`'s pages, then writes the result to a
    /// temporary file for the result sheet to save or share.
    func merge(_ session: MergeSession) async {
        guard !isMerging, !session.pages.isEmpty else { return }
        isMerging = true
        defer { isMerging = false }
        do {
            let result = try await session.makeMergedPDF()
            let name = session.files.count == 1 ? "\(session.files[0].name) (edited)" : "Merged"
            let url = try Self.writeTemporary(result.data, named: name)
            outcome = MergeOutcome(url: url, size: result.data.count,
                                   percentSaved: result.percentSaved, pageCount: result.pageCount)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes the temporary file behind `outcome` once its sheet is gone.
    func discard(_ outcome: MergeOutcome) {
        try? FileManager.default.removeItem(at: outcome.url.deletingLastPathComponent())
    }

    static let importsDirectory = FileManager.default.temporaryDirectory.appending(path: "Imports", directoryHint: .isDirectory)
    private static let exportsDirectory = FileManager.default.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory)

    /// Writes `data` as `<name>.pdf` in a directory of its own, so the shared
    /// or saved file keeps a readable name however many merges are made.
    private static func writeTemporary(_ data: Data, named name: String) throws -> URL {
        let directory = exportsDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(name).pdf")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Whether `url` is a copy made for this app: one the system placed in
    /// Documents/Inbox when another app shared a file, or one a drop wrote.
    /// Files opened in place are the user's own and are never deleted.
    private static func isDisposableCopy(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let documents = URL.documentsDirectory.standardizedFileURL.path
        return path.hasPrefix(documents + "/Inbox/") || path.hasPrefix(importsDirectory.standardizedFileURL.path + "/")
    }

    /// Removes temporary files a previous run left behind, for example after
    /// being terminated with a result sheet open.
    static func removeLeftovers() {
        try? FileManager.default.removeItem(at: importsDirectory)
        try? FileManager.default.removeItem(at: exportsDirectory)
    }
}

/// A finished merge, written to a temporary file.
struct MergeOutcome: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int
    let percentSaved: Int?
    let pageCount: Int
}
