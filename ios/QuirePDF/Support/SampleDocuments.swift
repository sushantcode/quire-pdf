#if DEBUG
import QuireKit
import UIKit

/// PDFs made in code for tests and screenshots, so neither depends on the
/// system document picker. Debug builds only.
///
/// - `-UITestSamples`: "Sample A" (3 pages) and "Sample B" (4 pages), each page
///   labelled with its file and number, for UI tests to read back.
/// - `-ScreenshotSamples`: three realistic documents for App Store screenshots.
enum SampleDocuments {
    static func make() -> [PDFFile] {
        [labelled(name: "Sample A", pages: 3), labelled(name: "Sample B", pages: 4)].compactMap { $0 }
    }

    static func screenshotSet() -> [PDFFile] {
        [lease(), receipts(), sitePhotos()].compactMap { $0 }
    }

    private static let letter = CGRect(x: 0, y: 0, width: 612, height: 792)

    private static func file(_ name: String, draw: (UIGraphicsPDFRendererContext) -> Void) -> PDFFile? {
        try? PDFFile(name: name, data: UIGraphicsPDFRenderer(bounds: letter).pdfData(actions: draw))
    }

    private static func labelled(name: String, pages: Int) -> PDFFile? {
        file(name) { context in
            for number in 1...pages {
                context.beginPage()
                ("\(name), page \(number)" as NSString)
                    .draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.systemFont(ofSize: 36, weight: .bold)])
            }
        }
    }

    // MARK: Screenshot documents

    private static func lease() -> PDFFile? {
        let sections = [
            ("1. Premises", "The landlord leases to the tenant the apartment described in Schedule A, together with the use of shared areas, for the term and rent set out below."),
            ("2. Term", "The lease begins on the first day of the month after signing and runs for twelve months. Either party may end it at the close of the term with sixty days' written notice."),
            ("3. Rent", "Rent is due on the first of each month. Payments received after the fifth carry a late fee as described in Section 9."),
            ("4. Deposit", "A security deposit equal to one month's rent is held for the term and returned within thirty days of move-out, less any documented repairs."),
            ("5. Maintenance", "The tenant keeps the premises clean and reports needed repairs promptly. The landlord maintains the structure, plumbing, heating and electrical systems."),
            ("6. Utilities", "Water and refuse collection are included. Electricity, internet and gas are the tenant's responsibility."),
        ]
        return file("Lease") { context in
            for page in 0..<3 {
                context.beginPage()
                var y: CGFloat = 72
                if page == 0 {
                    draw("Residential Lease Agreement", at: &y, font: .systemFont(ofSize: 26, weight: .bold))
                    draw("Between the landlord and tenant named in Schedule A", at: &y, font: .systemFont(ofSize: 13), color: .secondaryLabel)
                    y += 18
                }
                for (title, body) in sections.dropFirst(page * 2).prefix(page == 2 ? 2 : 3) {
                    draw(title, at: &y, font: .systemFont(ofSize: 15, weight: .semibold))
                    draw(body, at: &y, font: .systemFont(ofSize: 12), lineSpacing: 4)
                    y += 14
                }
                if page == 2 {
                    y += 40
                    for party in ["Landlord", "Tenant"] {
                        UIColor.label.setStroke()
                        let line = UIBezierPath()
                        line.move(to: CGPoint(x: 72, y: y + 30))
                        line.addLine(to: CGPoint(x: 330, y: y + 30))
                        line.stroke()
                        y += 36
                        draw(party + " signature and date", at: &y, font: .systemFont(ofSize: 11), color: .secondaryLabel)
                        y += 24
                    }
                }
                footer("Page \(page + 1) of 3")
            }
        }
    }

    private static func receipts() -> PDFFile? {
        let months = [
            ("March", [("Office chair", "249.00"), ("Desk lamp", "39.50"), ("Monitor stand", "64.99"), ("Cables", "18.75")]),
            ("April", [("Printer paper", "22.40"), ("Laptop sleeve", "34.00"), ("Notebook set", "15.60"), ("Software licence", "99.00"), ("Courier", "12.80")]),
        ]
        return file("Receipts") { context in
            for (month, items) in months {
                context.beginPage()
                UIColor.systemTeal.withAlphaComponent(0.85).setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: 612, height: 110))
                var y: CGFloat = 40
                draw("Expense receipts · \(month)", at: &y, font: .systemFont(ofSize: 24, weight: .bold), color: .white)
                y = 150
                for (item, amount) in items {
                    UIColor.secondarySystemBackground.setFill()
                    UIBezierPath(roundedRect: CGRect(x: 60, y: y - 8, width: 492, height: 38), cornerRadius: 6).fill()
                    (item as NSString).draw(at: CGPoint(x: 76, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 15)])
                    let price = "$" + amount as NSString
                    let width = price.size(withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium)]).width
                    price.draw(at: CGPoint(x: 536 - width, y: y),
                               withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium)])
                    y += 48
                }
                let total = items.compactMap { Double($0.1) }.reduce(0, +)
                y += 10
                let totalText = String(format: "Total  $%.2f", total) as NSString
                totalText.draw(at: CGPoint(x: 380, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 18, weight: .bold)])
                footer("Receipts · \(month)")
            }
        }
    }

    private static func sitePhotos() -> PDFFile? {
        let photos: [(String, [UIColor])] = [
            ("North elevation, morning light", [.systemOrange, .systemPink]),
            ("Courtyard after planting", [.systemGreen, .systemTeal]),
        ]
        return file("Site Photos") { context in
            for (caption, colors) in photos {
                context.beginPage()
                let frame = CGRect(x: 60, y: 90, width: 492, height: 520)
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: colors.map(\.cgColor) as CFArray, locations: [0, 1]) {
                    let cg = context.cgContext
                    cg.saveGState()
                    cg.addPath(UIBezierPath(roundedRect: frame, cornerRadius: 10).cgPath)
                    cg.clip()
                    cg.drawLinearGradient(gradient, start: CGPoint(x: frame.minX, y: frame.minY),
                                          end: CGPoint(x: frame.maxX, y: frame.maxY), options: [])
                    // Hills and a sun, so it reads as a picture at thumbnail size.
                    UIColor.white.withAlphaComponent(0.85).setFill()
                    UIBezierPath(ovalIn: CGRect(x: frame.maxX - 150, y: frame.minY + 50, width: 90, height: 90)).fill()
                    UIColor.black.withAlphaComponent(0.18).setFill()
                    let hills = UIBezierPath()
                    hills.move(to: CGPoint(x: frame.minX, y: frame.maxY))
                    hills.addCurve(to: CGPoint(x: frame.maxX, y: frame.maxY - 120),
                                   controlPoint1: CGPoint(x: frame.minX + 160, y: frame.maxY - 260),
                                   controlPoint2: CGPoint(x: frame.maxX - 180, y: frame.maxY - 20))
                    hills.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
                    hills.close()
                    hills.fill()
                    cg.restoreGState()
                }
                var y = frame.maxY + 24
                draw(caption, at: &y, font: .systemFont(ofSize: 16, weight: .semibold))
                draw("Site visit report, appendix B", at: &y, font: .systemFont(ofSize: 12), color: .secondaryLabel)
                footer("Site Photos")
            }
        }
    }

    // MARK: Drawing

    private static func draw(_ text: String, at y: inout CGFloat, font: UIFont,
                             color: UIColor = .label, lineSpacing: CGFloat = 2) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        let bounds = (text as NSString).boundingRect(with: CGSize(width: 468, height: CGFloat.greatestFiniteMagnitude),
                                                     options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        (text as NSString).draw(in: CGRect(x: 72, y: y, width: 468, height: bounds.height + 2), withAttributes: attributes)
        y += bounds.height + 8
    }

    private static func footer(_ text: String) {
        (text as NSString).draw(at: CGPoint(x: 72, y: 750),
                                withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.secondaryLabel])
    }
}
#endif
