import SwiftUI

struct ArticleCardView: View {
    let article: Article
    var onBookmark: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            if let url = article.thumbnailURL {
                RemoteImage(url: url, targetWidth: 88) {
                    thumbnailPlaceholder
                }
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                thumbnailPlaceholder
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                TagChipView(category: article.category)

                Text(article.title)
                    .font(.custom("Georgia", size: 15).weight(.semibold))
                    .foregroundColor(.miltonText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text("By \(article.author)")
                    Text("·")
                    Text(article.publishedDate.miltonRelative)
                }
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
            }

            Spacer(minLength: 0)

            // Bookmark button
            if let onBookmark {
                Button(action: onBookmark) {
                    Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundColor(article.isBookmarked ? .miltonAccent : .miltonSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(article.isBookmarked ? "Remove bookmark" : "Bookmark article")
            }
        }
        .padding(14)
        .miltonCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Article: \(article.title), by \(article.author), \(article.publishedDate.miltonFormatted), \(article.category)")
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.miltonPrimary.opacity(0.08)
            Image(systemName: "newspaper")
                .foregroundColor(.miltonPrimary.opacity(0.3))
                .font(.system(size: 24))
        }
    }
}
