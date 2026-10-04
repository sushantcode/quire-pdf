#if DEBUG
import QuireKit
import UIKit

/// Two small labelled PDFs, loaded when the app is launched with
/// `-UITestSamples`, so UI tests do not depend on the document picker.
/// Debug builds only.
enum SampleDocuments {
    static func make() -> [PDFFile] {
        [makeFile(name: "Sample A", pages: 3), makeFile(name: "Sample B", pages: 4)].compactMap { $0 }
    }

    private static func makeFile(name: String, pages: Int) -> PDFFile? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            for number in 1...pages {
                context.beginPage()
                let label = "\(name), page \(number)" as NSString
                label.draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.systemFont(ofSize: 36, weight: .bold)])
            }
        }
        return try? PDFFile(name: name, data: data)
    }
}
#endif
