import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import QuirePDF

/// Builds a PDF whose pages have widths `widths`, so page order can be read back from the output.
private func makePDF(widths: [CGFloat], height: CGFloat = 400, noiseImage: Bool = false) -> Data {
    let data = NSMutableData()
    let consumer = CGDataConsumer(data: data as CFMutableData)!
    let context = CGContext(consumer: consumer, mediaBox: nil, nil)!
    for width in widths {
        var box = CGRect(x: 0, y: 0, width: width, height: height)
        let boxData = Data(bytes: &box, count: MemoryLayout<CGRect>.size) as CFData
        context.beginPDFPage([kCGPDFContextMediaBox as String: boxData] as CFDictionary)
        if noiseImage {
            context.draw(makeNoiseImage(side: 1200), in: box)
        } else {
            context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
            context.fill(box.insetBy(dx: 20, dy: 20))
        }
        context.endPDFPage()
    }
    context.closePDF()
    return data as Data
}

/// Deterministic pseudo-random pixels: compresses poorly losslessly, well as JPEG.
private func makeNoiseImage(side: Int) -> CGImage {
    var state: UInt32 = 12345
    var bytes = [UInt8](repeating: 0, count: side * side * 4)
    for i in stride(from: 0, to: bytes.count, by: 4) {
        state = state &* 1_664_525 &+ 1_013_904_223
        bytes[i] = UInt8(truncatingIfNeeded: state >> 24)
        bytes[i + 1] = UInt8(truncatingIfNeeded: state >> 16)
        bytes[i + 2] = UInt8(truncatingIfNeeded: state >> 8)
        bytes[i + 3] = 255
    }
    let context = CGContext(data: &bytes, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    return context.makeImage()!
}

private func pageWidths(_ data: Data) -> [Int] {
    let document = PDFDocument(data: data)!
    return (0..<document.pageCount).map { Int(document.page(at: $0)!.bounds(for: .mediaBox).width) }
}

private struct Item: Identifiable, Equatable {
    let id: Int
}

@MainActor
struct PageMoveTests {
    @Test func movingForwardTakesTargetPosition() {
        var items = [1, 2, 3, 4].map(Item.init)
        items.move(1, onto: 3)
        #expect(items.map(\.id) == [2, 3, 1, 4])
    }

    @Test func movingBackwardTakesTargetPosition() {
        var items = [1, 2, 3, 4].map(Item.init)
        items.move(4, onto: 2)
        #expect(items.map(\.id) == [1, 4, 2, 3])
    }

    @Test func unknownIDsLeaveOrderUnchanged() {
        var items = [1, 2, 3].map(Item.init)
        items.move(9, onto: 2)
        items.move(2, onto: 2)
        #expect(items.map(\.id) == [1, 2, 3])
    }
}

@MainActor
struct MergeTests {
    @Test func mergesFilesAndPagesInEditedOrder() throws {
        let workspace = Workspace()
        let a = try PDFFile(name: "a", data: makePDF(widths: [101, 102, 103]))
        let b = try PDFFile(name: "b", data: makePDF(widths: [201, 202]))
        workspace.files = [a, b]

        a.movePage(a.pages[2].id, onto: a.pages[0].id)   // a: 103, 101, 102
        a.removePages([a.pages[1].id])                   // a: 103, 102
        workspace.moveFiles(from: [1], to: 0)            // b before a

        let merged = try PDFComposer.merge(workspace.pagesForMerge)
        #expect(pageWidths(merged) == [201, 202, 103, 102])
        #expect(a.document.pageCount == 3, "merging must not alter the source document")
    }

    @Test func resetRestoresOriginalPages() throws {
        let file = try PDFFile(name: "a", data: makePDF(widths: [101, 102, 103]))
        file.removePages([file.pages[0].id])
        #expect(file.isModified)
        file.resetPages()
        #expect(!file.isModified)
        #expect(file.pages.count == 3)
    }

    @Test func mergingNothingFails() {
        #expect(throws: PDFComposer.ComposeError.self) { try PDFComposer.merge([]) }
    }

    @Test func rejectsNonPDFData() {
        #expect(throws: PDFFile.LoadError.self) { try PDFFile(name: "x", data: Data("hello".utf8)) }
    }
}

struct CompressionTests {
    @Test func maximumShrinksImageHeavyPDFAndKeepsPages() throws {
        let input = makePDF(widths: [612, 500], height: 792, noiseImage: true)
        let output = try PDFCompressor.compress(input, level: .maximum)
        #expect(output.count < input.count / 4, "expected big reduction, got \(input.count) -> \(output.count)")
        #expect(pageWidths(output) == [612, 500])
    }

    @Test func rasterizeKeepsRotatedPageOrientation() throws {
        let document = PDFDocument(data: makePDF(widths: [300], height: 500))!
        document.page(at: 0)!.rotation = 90
        let rotated = document.dataRepresentation()!
        let output = try PDFCompressor.rasterize(rotated, dpi: 72, jpegQuality: 0.5)
        let box = PDFDocument(data: output)!.page(at: 0)!.bounds(for: .mediaBox)
        #expect(box.size == CGSize(width: 500, height: 300))
    }

    @Test(arguments: CompressionLevel.allCases)
    func neverGrowsTheFile(level: CompressionLevel) throws {
        let input = makePDF(widths: [612, 612, 612], height: 792)
        let output = try PDFCompressor.compress(input, level: level)
        #expect(output.count <= input.count)
        #expect(PDFDocument(data: output)?.pageCount == 3)
    }
}
