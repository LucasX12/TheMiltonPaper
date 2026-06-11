import SwiftUI

struct FeaturedArticleView: View {
    let article: Article
    var onBookmark: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero image
            ZStack(alignment: .bottomLeading) {
                if let url = article.thumbnailURL {
                    RemoteImage(url: url, targetWidth: 400) {
                        heroPlaceholder
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                } else {
                    heroPlaceholder
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                }

                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                TagChipView(category: article.category, style: .solid)
                    .padding(14)
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(.miltonHeadline)
                    .foregroundColor(.miltonText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(article.summary)
                    .font(.miltonBody)
                    .foregroundColor(.miltonSecondary)
                    .lineLimit(2)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                        Text("By \(article.author)")
                        Text("·")
                        Text(article.publishedDate.miltonFormatted)
                    }
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)

                    Spacer()

                    if let onBookmark {
                        Button(action: onBookmark) {
                            Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 17))
                                .foregroundColor(article.isBookmarked ? .miltonAccent : .miltonSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(article.isBookmarked ? "Remove bookmark" : "Bookmark article")
                    }
                }
            }
            .padding(16)
        }
        .miltonCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Featured: \(article.title), by \(article.author)")
    }

    private var heroPlaceholder: some View {
        ZStack {
            Color.miltonPrimary.opacity(0.1)
            Image(systemName: "newspaper.fill")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(.miltonPrimary.opacity(0.25))
        }
    }
}
