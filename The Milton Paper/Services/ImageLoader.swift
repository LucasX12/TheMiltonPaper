import Foundation
import UIKit
import ImageIO

/// Downloads, downsamples, and caches remote images.
///
/// - Decoded images are kept in an `NSCache` keyed by URL + target width.
/// - Network responses flow through the shared `URLCache` for disk reuse.
/// - Squarespace CDN URLs are rewritten to request an appropriately sized
///   rendition instead of the multi-megabyte original upload.
actor ImageLoader {
    static let shared = ImageLoader()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024 // ~64 MB of decoded pixels
        return cache
    }()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    /// - Parameter maxPixelWidth: cap for the decoded bitmap, in pixels
    ///   (display points × screen scale).
    func image(for url: URL, maxPixelWidth: CGFloat) async -> UIImage? {
        let requestURL = url.squarespaceSized(forPixelWidth: maxPixelWidth)
        let key = "\(requestURL.absoluteString)|\(Int(maxPixelWidth))"

        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let existing = inFlight[key] { return await existing.value }

        let task = Task<UIImage?, Never> {
            var request = URLRequest(url: requestURL)
            request.cachePolicy = .returnCacheDataElseLoad
            guard let (data, _) = try? await URLSession.shared.data(for: request) else {
                return nil
            }
            return Self.downsampledImage(from: data, maxPixelWidth: maxPixelWidth)
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil

        if let image {
            let cost = Int(image.size.width * image.size.height
                           * image.scale * image.scale * 4)
            cache.setObject(image, forKey: key as NSString, cost: cost)
        }
        return image
    }

    /// Decodes at a capped pixel size so large originals never hold a
    /// full-resolution bitmap in memory.
    private static func downsampledImage(from data: Data, maxPixelWidth: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(64, maxPixelWidth)
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}

extension URL {
    /// Squarespace's image CDN serves resized renditions via the `format`
    /// query parameter (e.g. `?format=750w`); other hosts are left untouched.
    func squarespaceSized(forPixelWidth width: CGFloat) -> URL {
        guard let host = host?.lowercased(),
              host.contains("squarespace") || host.contains("sqspcdn") else {
            return self
        }
        let buckets = [100, 300, 500, 750, 1000, 1500, 2500]
        let target = buckets.first(where: { CGFloat($0) >= width }) ?? 2500
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        var items = (components.queryItems ?? []).filter { $0.name != "format" }
        items.append(URLQueryItem(name: "format", value: "\(target)w"))
        components.queryItems = items
        return components.url ?? self
    }
}
