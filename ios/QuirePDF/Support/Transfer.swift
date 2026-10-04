import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// A PDF dropped onto the app, for example dragged from Files on iPad. The
/// system hands over a file that disappears after the drop, so it is copied
/// somewhere the app controls; `ScreenState.add` deletes the copy once read.
nonisolated struct DroppedPDF: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .pdf) { received in
            let directory = FileManager.default.temporaryDirectory
                .appending(path: "Imports/\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let copy = directory.appending(path: received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return DroppedPDF(url: copy)
        }
    }
}

/// The merged file, for `fileExporter`, which saves a document rather than a URL.
nonisolated struct MergedPDFDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
