import SwiftUI

/// Drop-in replacement for `AsyncImage` backed by `ImageLoader`:
/// in-memory caching, downsampled decoding, and CDN-sized requests.
/// Shows a shimmer while loading and the supplied placeholder on failure.
struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    /// Width in points the image will be displayed at (caps the decode size).
    var targetWidth: CGFloat
    @ViewBuilder var failurePlaceholder: () -> Placeholder

    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if didFail || url == nil {
                failurePlaceholder()
            } else {
                ShimmerView()
            }
        }
        .task(id: url) {
            guard let url else {
                loadedImage = nil
                didFail = false
                return
            }
            let scale = max(1, displayScale)
            if let image = await ImageLoader.shared.image(for: url, maxPixelWidth: targetWidth * scale) {
                loadedImage = image
                didFail = false
            } else if !Task.isCancelled {
                loadedImage = nil
                didFail = true
            }
        }
    }
}
