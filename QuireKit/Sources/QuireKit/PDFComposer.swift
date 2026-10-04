import CoreGraphics
import CoreText
import Foundation
import ImageIO
import PDFKit
#if os(macOS)
import Quartz
#endif
import UniformTypeIdentifiers

public nonisolated enum CompressionLevel: String, CaseIterable, Identifiable, Sendable {
    case none
    case balanced
    case maximum

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: "None"
        case .balanced: "Balanced"
        case .maximum: "Maximum"
        }
    }

    public var detail: String {
        switch self {
        case .none: "Keeps the original content exactly."
        case .balanced: "Shrinks images to JPEG at up to 150 dpi. Text stays selectable."
        case .maximum: "Renders every page as a JPEG image. Smallest file, but text is no longer selectable."
        }
    }
}

public enum PDFComposer {
    public enum ComposeError: LocalizedError {
        case noPages
        case encodingFailed

        public var errorDescription: String? {
            switch self {
            case .noPages: "There are no pages to merge."
            case .encodingFailed: "The merged PDF could not be written."
            }
        }
    }

    /// Builds one document from `pages`, in order. Pages are copied so the
    /// source documents are not modified.
    public static func merge(_ pages: [PDFPage]) throws -> Data {
        guard !pages.isEmpty else { throw ComposeError.noPages }
        let merged = PDFDocument()
        for page in pages {
            guard let copy = page.copy() as? PDFPage else { continue }
            merged.insert(copy, at: merged.pageCount)
        }
        guard let data = merged.dataRepresentation() else { throw ComposeError.encodingFailed }
        return data
    }
}

/// Size reduction for finished PDF data. Works on bytes only, so it can run off the main actor.
public nonisolated enum PDFCompressor {
    static let balancedDPI = 150
    static let balancedJPEGQuality = 0.75
    static let rasterDPI: CGFloat = 110
    static let rasterJPEGQuality: CGFloat = 0.5

    /// Returns the compressed data, or the input unchanged if compression
    /// would not make it smaller.
    public static func compress(_ data: Data, level: CompressionLevel) throws -> Data {
        let output: Data
        switch level {
        case .none:
            return data
        case .balanced:
            output = try smallestReencoding(of: data)
        case .maximum:
            output = try rasterize(data, dpi: rasterDPI, jpegQuality: rasterJPEGQuality)
        }
        return output.count < data.count ? output : data
    }

#if os(macOS)
    /// Rewrites the images through a Quartz filter, the mechanism behind
    /// Preview's Reduce File Size: images are re-encoded while text and
    /// vector content are copied as they are.
    ///
    /// PDFKit's own `saveImagesAsJPEGOption` and `optimizeImagesForScreenOption`
    /// are not used: measured, they write the input back unchanged.
    ///
    /// Two passes, keeping the smaller. A filter that downsamples to a
    /// resolution also *upsamples* images below it, which can make a PDF of
    /// small images many times larger; a filter that only re-encodes never
    /// does, but leaves large JPEGs almost as big. No single filter setting
    /// scales down only, and `ImageSizeMin`, which looks like it should, hangs.
    static func smallestReencoding(of data: Data) throws -> Data {
        guard let document = PDFDocument(data: data) else { throw PDFComposer.ComposeError.encodingFailed }
        let jpeg: [String: Any] = [
            "Compression Quality": balancedJPEGQuality,
            "ImageCompression": "ImageJPEGCompress",
        ]
        var downsampled = jpeg
        downsampled["ImageScaleSettings"] = [
            "ImageResolution": balancedDPI,
            "ImageScaleInterpolate": true,
            "ImageSizeMax": 3000,
            "ImageSizeMin": 0,
        ]
        let candidates = [downsampled, jpeg].compactMap { settings -> Data? in
            let properties: [String: Any] = [
                "Name": "Quire PDF Balanced",
                "FilterType": 1,
                "Domains": ["Applications": true],
                "FilterData": ["ColorSettings": ["ImageSettings": settings]],
            ]
            guard let filter = QuartzFilter(properties: properties) else { return nil }
            return document.dataRepresentation(options: [PDFDocumentWriteOption(rawValue: "QuartzFilter"): filter])
        }
        guard let smallest = candidates.min(by: { $0.count < $1.count }) else {
            throw PDFComposer.ComposeError.encodingFailed
        }
        return smallest
    }
#else
    /// iOS has no Quartz filters, and PDFKit's own image options write the
    /// input back unchanged there too, so images are re-encoded page by page.
    static func smallestReencoding(of data: Data) throws -> Data {
        try reencodeImagePages(of: data)
    }
#endif

    /// Redraws each page that holds images as one JPEG at `balancedDPI`, when
    /// that at least halves the page, and copies every other page unchanged.
    ///
    /// A redrawn page gets an invisible text layer, drawn character by
    /// character where PDFKit reports each one, so its text stays selectable
    /// and searchable, as in a scanned document. Its links and annotations
    /// are not carried over. Pages without images, which is most text and
    /// vector content, are never redrawn: they would only get bigger.
    ///
    /// Not platform-specific, so its tests run on macOS as well as iOS.
    static func reencodeImagePages(of data: Data) throws -> Data {
        guard let document = PDFDocument(data: data),
              let provider = CGDataProvider(data: data as CFData),
              let source = CGPDFDocument(provider)
        else { throw PDFComposer.ComposeError.encodingFailed }

        let scale = CGFloat(balancedDPI) / 72
        var replacements: [(index: Int, page: PDFPage)] = []
        // A PDFPage holds its document weakly; keep the redrawn ones alive.
        var redrawnDocuments: [PDFDocument] = []
        for index in 0..<document.pageCount {
            autoreleasepool {
                guard let page = document.page(at: index),
                      let cgPage = source.page(at: index + 1),
                      hasImages(cgPage),
                      let redrawn = redraw(cgPage, text: page, scale: scale, quality: balancedJPEGQuality),
                      redrawn.count * 2 < singlePageSize(page),
                      let redrawnDocument = PDFDocument(data: redrawn),
                      let newPage = redrawnDocument.page(at: 0)
                else { return }
                redrawnDocuments.append(redrawnDocument)
                replacements.append((index, newPage))
            }
        }
        guard !replacements.isEmpty else { return data }
        for (index, page) in replacements {
            document.removePage(at: index)
            document.insert(page, at: index)
        }
        guard let output = document.dataRepresentation() else { throw PDFComposer.ComposeError.encodingFailed }
        return output
    }

    /// Whether the page's resources include an image. Inline images are not
    /// seen, which only means such a page is left as it is.
    private static func hasImages(_ page: CGPDFPage) -> Bool {
        guard let dictionary = page.dictionary else { return false }
        var resources: CGPDFDictionaryRef?
        var xObjects: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources), let resources,
              CGPDFDictionaryGetDictionary(resources, "XObject", &xObjects), let xObjects
        else { return false }
        var found = false
        CGPDFDictionaryApplyBlock(xObjects, { _, object, _ in
            var stream: CGPDFStreamRef?
            var subtype: UnsafePointer<CChar>?
            if CGPDFObjectGetValue(object, .stream, &stream), let stream,
               let streamDictionary = CGPDFStreamGetDictionary(stream),
               CGPDFDictionaryGetName(streamDictionary, "Subtype", &subtype), let subtype,
               String(cString: subtype) == "Image" {
                found = true
                return false
            }
            return true
        }, nil)
        return found
    }

    /// The bytes `page` takes on its own: what redrawing it has to beat.
    private static func singlePageSize(_ page: PDFPage) -> Int {
        guard let copy = page.copy() as? PDFPage else { return 0 }
        let single = PDFDocument()
        single.insert(copy, at: 0)
        return single.dataRepresentation()?.count ?? 0
    }

    /// One page as a JPEG, with `text`'s characters drawn invisibly on top.
    private static func redraw(_ page: CGPDFPage, text: PDFPage, scale: CGFloat, quality: CGFloat) -> Data? {
        let box = page.getBoxRect(.cropBox)
        let quarterTurned = page.rotationAngle % 180 != 0
        let size = quarterTurned ? CGSize(width: box.height, height: box.width) : box.size
        var pageRect = CGRect(origin: .zero, size: size)
        guard let image = renderJPEG(page, size: size, scale: scale, quality: quality) else { return nil }

        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil)
        else { return nil }
        context.beginPDFPage(nil)
        context.draw(image, in: pageRect)
        // The same mapping the image was rendered with, so each invisible
        // character lands on its picture, rotated pages included.
        context.concatenate(page.getDrawingTransform(.cropBox, rect: pageRect, rotate: 0, preserveAspectRatio: true))
        drawInvisibleText(of: text, in: context)
        context.endPDFPage()
        context.closePDF()
        return output as Data
    }

    /// Draws each line of `page`'s text invisibly where it appears. Every
    /// character keeps its own position and width, but a line shares one size
    /// and baseline: placed one by one, a comma or a period sits low enough
    /// that text extraction reads it as a line of its own.
    private static func drawInvisibleText(of page: PDFPage, in context: CGContext) {
        guard let string = page.string, !string.isEmpty else { return }
        let characters = string as NSString
        var fonts: [Int: CTFont] = [:]
        context.setTextDrawingMode(.invisible)

        // PDFKit separates lines with newlines, so each run between them is a line.
        var lineStart = 0
        for index in 0...characters.length {
            let atEnd = index == characters.length
            guard atEnd || characters.substring(with: NSRange(location: index, length: 1))
                .rangeOfCharacter(from: .newlines) != nil
            else { continue }
            let glyphs = (lineStart..<index).compactMap { i -> (String, CGRect)? in
                let bounds = page.characterBounds(at: i)
                guard bounds.width > 0, bounds.height > 0 else { return nil }
                return (characters.substring(with: NSRange(location: i, length: 1)), bounds)
            }
            lineStart = index + 1
            guard let lineRect = glyphs.map(\.1).reduce(nil, { ($0 ?? $1).union($1) }) else { continue }

            let pointSize = max(1, Int((lineRect.height * 0.8).rounded()))
            let font = fonts[pointSize] ?? CTFontCreateWithName("Helvetica" as CFString, CGFloat(pointSize), nil)
            fonts[pointSize] = font
            let baseline = lineRect.minY + CTFontGetDescent(font)
            for (character, bounds) in glyphs {
                let line = CTLineCreateWithAttributedString(
                    NSAttributedString(string: character, attributes: [kCTFontAttributeName as NSAttributedString.Key: font]))
                let width = CTLineGetTypographicBounds(line, nil, nil, nil)
                // Stretched to the character's width, so selection covers what is shown.
                context.textMatrix = CGAffineTransform(scaleX: width > 0 ? bounds.width / width : 1, y: 1)
                context.textPosition = CGPoint(x: bounds.minX, y: baseline)
                CTLineDraw(line, context)
            }
        }
    }

    /// Redraws each page as a single JPEG image at `dpi`, keeping the page's
    /// visible size and orientation.
    static func rasterize(_ data: Data, dpi: CGFloat, jpegQuality: CGFloat) throws -> Data {
        guard let provider = CGDataProvider(data: data as CFData),
              let source = CGPDFDocument(provider),
              source.numberOfPages > 0
        else { throw PDFComposer.ComposeError.encodingFailed }

        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { throw PDFComposer.ComposeError.encodingFailed }

        let scale = dpi / 72
        for index in 1...source.numberOfPages {
            guard let page = source.page(at: index) else { continue }
            try autoreleasepool {
                let box = page.getBoxRect(.cropBox)
                let quarterTurned = page.rotationAngle % 180 != 0
                let size = quarterTurned ? CGSize(width: box.height, height: box.width) : box.size
                let pageRect = CGRect(origin: .zero, size: size)

                guard let image = renderJPEG(page, size: size, scale: scale, quality: jpegQuality)
                else { throw PDFComposer.ComposeError.encodingFailed }

                var mediaBox = pageRect
                let boxData = Data(bytes: &mediaBox, count: MemoryLayout<CGRect>.size) as CFData
                pdf.beginPDFPage([kCGPDFContextMediaBox as String: boxData] as CFDictionary)
                pdf.draw(image, in: pageRect)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return output as Data
    }

    /// Renders `page` to a bitmap and returns it as a JPEG-backed image, so
    /// Quartz embeds the JPEG bytes rather than re-encoding raw pixels.
    private static func renderJPEG(_ page: CGPDFPage, size: CGSize, scale: CGFloat, quality: CGFloat) -> CGImage? {
        let width = max(1, Int((size.width * scale).rounded()))
        let height = max(1, Int((size.height * scale).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.scaleBy(x: scale, y: scale)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(origin: .zero, size: size),
                                                     rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        guard let bitmap = context.makeImage() else { return nil }

        let jpeg = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(jpeg, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, bitmap,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination),
              let jpegSource = CGImageSourceCreateWithData(jpeg, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(jpegSource, 0, nil)
    }
}
