import Foundation
import Observation
import QuireKit

/// What the window shows besides the document: panels, confirmations, and the
/// last problem to report. The document itself is the shared `MergeSession`.
@Observable
final class WindowState {
    var isImporting = false
    /// Set to ask before `MergeSession.clear()`; the window shows the confirmation.
    var isConfirmingClear = false
    /// Set by the menu command; the merge bar runs the export and clears it.
    var isExportRequested = false
    var errorMessage: String?

    /// Adds `urls` to `session` and reports any that could not be read.
    func add(_ urls: [URL], to session: MergeSession, at index: Int? = nil) {
        let result = session.add(urls, at: index)
        if !result.failures.isEmpty { errorMessage = result.failures.joined(separator: "\n") }
    }
}
