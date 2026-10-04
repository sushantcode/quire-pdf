import QuireKit
import SwiftUI

/// Shown once a merge finishes: what was made, how to keep it, and a way to
/// start the next one. Keeping the pages until the person chooses lets them
/// save a second copy or fix a mistake without loading everything again.
struct MergeResultSheet: View {
    let outcome: MergeOutcome
    @Environment(MergeSession.self) private var session
    @Environment(ScreenState.self) private var screen
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportDocument: MergedPDFDocument?
    @State private var savedToFiles = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                        Text("Merged \(outcome.pageCount.counted("page"))")
                            .font(.title2.bold())
                        Text(summary)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        ShareLink(item: outcome.url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            exportDocument = (try? Data(contentsOf: outcome.url)).map(MergedPDFDocument.init(data:))
                            isExporting = exportDocument != nil
                        } label: {
                            Label(savedToFiles ? "Saved to Files" : "Save to Files",
                                  systemImage: savedToFiles ? "checkmark" : "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            session.clear()
                            dismiss()
                        } label: {
                            Label("Start New Merge", systemImage: "plus.square.on.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Removes these files so you can merge others")
                    }
                    .controlSize(.large)
                    .frame(maxWidth: 420)

                    Text("Your original files are unchanged. Tap Done to keep editing these pages.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.success, trigger: outcome.id)
        .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .pdf,
                      defaultFilename: outcome.url.deletingPathExtension().lastPathComponent) { result in
            switch result {
            case .success: savedToFiles = true
            case .failure(let error): screen.errorMessage = error.localizedDescription
            }
        }
    }

    private var summary: String {
        let size = outcome.size.formatted(.byteCount(style: .file))
        let name = outcome.url.lastPathComponent
        if let percent = outcome.percentSaved {
            return String(localized: "\(name) · \(size), \(percent)% smaller")
        }
        return "\(name) · \(size)"
    }
}
