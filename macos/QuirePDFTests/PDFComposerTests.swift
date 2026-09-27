import AppKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
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

/// One letter-size page with a line of text above a large photo-like image.
private func makeTextAndImagePDF(text: String) -> Data {
    let data = NSMutableData()
    let context = CGContext(consumer: CGDataConsumer(data: data as CFMutableData)!, mediaBox: nil, nil)!
    context.beginPDFPage(nil)
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 24)]))
    context.textPosition = CGPoint(x: 72, y: 720)
    CTLineDraw(line, context)
    context.draw(makeNoiseImage(side: 2400), in: CGRect(x: 72, y: 72, width: 468, height: 600))
    context.endPDFPage()
    context.closePDF()
    return data as Data
}

/// A letter-size page showing a small, already-JPEG image at about 80 dpi:
/// the kind a downsampling filter would scale *up*.
private func makeLowResolutionJPEGPDF() -> Data {
    let jpeg = NSMutableData()
    let destination = CGImageDestinationCreateWithData(jpeg, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, makeNoiseImage(side: 600),
                               [kCGImageDestinationLossyCompressionQuality: 0.6] as CFDictionary)
    CGImageDestinationFinalize(destination)
    let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(jpeg, nil)!, 0, nil)!

    let data = NSMutableData()
    let context = CGContext(consumer: CGDataConsumer(data: data as CFMutableData)!, mediaBox: nil, nil)!
    context.beginPDFPage(nil)
    context.draw(image, in: CGRect(x: 36, y: 36, width: 540, height: 540))
    context.endPDFPage()
    context.closePDF()
    return data as Data
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

    @Test func movingSeveralKeepsTheirOrder() {
        var forward = [1, 2, 3, 4, 5].map(Item.init)
        forward.move([1, 3], onto: 4)
        #expect(forward.map(\.id) == [2, 4, 1, 3, 5])

        var backward = [1, 2, 3, 4, 5].map(Item.init)
        backward.move([5, 3], onto: 2)
        #expect(backward.map(\.id) == [1, 3, 5, 2, 4])
    }

    @Test func movingToStartAndEnd() {
        var items = [1, 2, 3, 4].map(Item.init)
        items.moveToStart([2, 4])
        #expect(items.map(\.id) == [2, 4, 1, 3])
        items.moveToEnd([2])
        #expect(items.map(\.id) == [4, 1, 3, 2])
    }
}

@MainActor
struct MergeTests {
    /// A workspace holding a (pages 101-103) and b (pages 201-204).
    private func makeWorkspace() throws -> (Workspace, PDFFile, PDFFile) {
        let workspace = Workspace()
        let a = try PDFFile(name: "a", data: makePDF(widths: [101, 102, 103]))
        let b = try PDFFile(name: "b", data: makePDF(widths: [201, 202, 203, 204]))
        workspace.insert([a, b])
        return (workspace, a, b)
    }

    private func mergedWidths(_ workspace: Workspace) throws -> [Int] {
        pageWidths(try PDFComposer.merge(workspace.pagesForMerge))
    }

    @Test func mergesEveryPageInFileOrderByDefault() throws {
        let (workspace, _, _) = try makeWorkspace()
        #expect(try mergedWidths(workspace) == [101, 102, 103, 201, 202, 203, 204])
        #expect(!workspace.isRearranged)
    }

    @Test func movesAPageFromALaterFileToTheTop() throws {
        let (workspace, a, b) = try makeWorkspace()
        workspace.movePages([b.pages[3].id], onto: a.pages[0].id)
        #expect(try mergedWidths(workspace) == [204, 101, 102, 103, 201, 202, 203])
        #expect(workspace.isModified(b))
        #expect(!workspace.isModified(a))
        #expect(b.document.pageCount == 4, "merging must not alter the source document")
    }

    @Test func reorderingFilesRegroupsTheirPages() throws {
        let (workspace, a, b) = try makeWorkspace()
        workspace.movePages([b.pages[0].id], onto: a.pages[1].id)  // 101, 201, 102, ...
        workspace.removePages([a.pages[0].id])
        workspace.moveFiles(from: [1], to: 0)
        #expect(try mergedWidths(workspace) == [201, 202, 203, 204, 102, 103])
    }

    @Test func addedFilesInsertTheirPagesAtTheirPosition() throws {
        let (workspace, _, _) = try makeWorkspace()
        let c = try PDFFile(name: "c", data: makePDF(widths: [301]))
        workspace.insert([c], at: 1)
        #expect(try mergedWidths(workspace) == [101, 102, 103, 301, 201, 202, 203, 204])
        #expect(Set(workspace.files.map(\.tintIndex)).count == 3, "each file gets its own colour")
    }

    @Test func removingAFileRemovesItsPages() throws {
        let (workspace, a, b) = try makeWorkspace()
        workspace.selectedPageIDs = [a.pages[0].id, b.pages[0].id]
        workspace.remove([a.id])
        #expect(try mergedWidths(workspace) == [201, 202, 203, 204])
        #expect(workspace.selectedPageIDs == [b.pages[0].id])
    }

    @Test func resetRestoresEveryPageInFileOrder() throws {
        let (workspace, a, b) = try makeWorkspace()
        workspace.movePagesToStart([b.pages[2].id])
        workspace.removePages([a.pages[1].id])
        #expect(workspace.isRearranged)
        workspace.resetPages()
        #expect(!workspace.isRearranged)
        #expect(workspace.pages.count == 7)
    }

    @Test func clearRemovesEverythingAndRestartsColours() throws {
        let (workspace, a, _) = try makeWorkspace()
        workspace.selectedPageIDs = [a.pages[0].id]
        workspace.selectedFileID = a.id
        workspace.clear()
        #expect(workspace.files.isEmpty && workspace.pages.isEmpty)
        #expect(workspace.selectedPageIDs.isEmpty && workspace.selectedFileID == nil)

        let c = try PDFFile(name: "c", data: makePDF(widths: [301]))
        workspace.insert([c])
        #expect(c.tintIndex == 0, "a fresh start begins at the first colour again")
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

    @Test func balancedShrinksImagesAndKeepsTextSelectable() throws {
        let input = makeTextAndImagePDF(text: "Selectable text survives")
        let output = try PDFCompressor.compress(input, level: .balanced)
        #expect(output.count < input.count / 4, "expected big reduction, got \(input.count) -> \(output.count)")
        #expect(PDFDocument(data: output)?.string?.contains("Selectable text survives") == true)
    }

    @Test func balancedDoesNotUpsampleLowResolutionImages() throws {
        let input = makeLowResolutionJPEGPDF()
        let output = try PDFCompressor.smallestReencoding(of: input)
        #expect(output.count <= input.count + input.count / 10,
                "re-encoding grew a low-resolution PDF: \(input.count) -> \(output.count)")
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
