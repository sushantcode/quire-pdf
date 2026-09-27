import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Quartz
import UniformTypeIdentifiers

nonisolated enum CompressionLevel: String, CaseIterable, Identifiable, Sendable {
    case none
    case balanced
    case maximum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .balanced: "Balanced"
        case .maximum: "Maximum"
        }
    }

    var detail: String {
        switch self {
        case .none: "Keeps the original content exactly."
        case .balanced: "Re-encodes images as JPEG, down to 150 dpi. Text stays selectable."
        case .maximum: "Renders every page as a JPEG image. Smallest file, but text is no longer selectable."
        }
    }
}

enum PDFComposer {
    enum ComposeError: LocalizedError {
        case noPages
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .noPages: "There are no pages to merge."
            case .encodingFailed: "The merged PDF could not be written."
            }
        }
    }

    /// Builds one document from `pages`, in order. Pages are copied so the
    /// source documents are not modified.
    static func merge(_ pages: [PDFPage]) throws -> Data {
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
nonisolated enum PDFCompressor {
    static let balancedDPI = 150
    static let balancedJPEGQuality = 0.75
    static let rasterDPI: CGFloat = 110
    static let rasterJPEGQuality: CGFloat = 0.5

    /// Returns the compressed data, or the input unchanged if compression
    /// would not make it smaller.
    static func compress(_ data: Data, level: CompressionLevel) throws -> Data {
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

        context.setFillColor(.white)
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
