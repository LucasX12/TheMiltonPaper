import SwiftUI

/// A writer's photo, falling back to the monogram circle the author page has
/// always drawn. The directory is looked up by name so callers only need the
/// byline string.
struct AuthorAvatarView: View {
    let name: String
    var size: CGFloat = 28

    @ObservedObject private var directory = WriterDirectoryService.shared

    private var writer: Writer? { directory.writer(named: name) }

    var body: some View {
        Group {
            if let photoURL = writer?.photoURL {
                RemoteImage(url: photoURL, targetWidth: size) { monogram }
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var monogram: some View {
        ZStack {
            Circle().fill(Color.miltonPrimary)
            Text(name.prefix(1).uppercased())
                .font(.custom("Georgia", size: size * 0.39).weight(.semibold))
                .foregroundColor(.white)
        }
    }
}
