import PDFKit
import QuireKit
import SwiftUI

/// A page thumbnail, sized to the page's aspect ratio. Rendered when it first
/// scrolls into view and kept in a cache, so scrolling back through a long
/// document does not render every page again.
struct PageThumbnail: View {
    let ref: PageRef
    /// The longest side to render, in points.
    let size: CGFloat
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    private var aspectRatio: CGFloat {
        let bounds = ref.page.bounds(for: .cropBox)
        let quarterTurned = ref.page.rotation % 180 != 0
        let width = quarterTurned ? bounds.height : bounds.width
        let height = quarterTurned ? bounds.width : bounds.height
        return height > 0 ? width / height : 1
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        .task(id: ref.id) {
            image = ThumbnailCache.shared.image(for: ref, pixels: size * displayScale)
        }
    }
}

/// Rendered thumbnails, keyed by page and size. Keys are page ids, which are
/// never reused, so a cleared session cannot show another file's picture.
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 400
    }

    func image(for ref: PageRef, pixels: CGFloat) -> UIImage {
        let key = "\(ref.id.uuidString)-\(Int(pixels))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let image = ref.page.thumbnail(of: CGSize(width: pixels, height: pixels), for: .cropBox)
        cache.setObject(image, forKey: key)
        return image
    }
}
