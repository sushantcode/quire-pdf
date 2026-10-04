import PDFKit
import QuireKit
import SwiftUI

/// One page, full size, zoomable: to check a page before deciding where it goes.
struct PagePreview: View {
    let ref: PageRef
    @Environment(MergeSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let position = (session.pages.firstIndex { $0.id == ref.id } ?? 0) + 1
        NavigationStack {
            SinglePageView(page: ref.page)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Page \(position)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if let file = session.file(ref.fileID) {
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 0) {
                                Text("Page \(position)").font(.headline)
                                Text("\(file.name) · page \(ref.number)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

/// A PDFKit view showing a copy of one page, so the source document is never
/// handed to a view that could change it.
private struct SinglePageView: UIViewRepresentable {
    let page: PDFPage

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.backgroundColor = .secondarySystemBackground
        let document = PDFDocument()
        if let copy = page.copy() as? PDFPage { document.insert(copy, at: 0) }
        view.document = document
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
