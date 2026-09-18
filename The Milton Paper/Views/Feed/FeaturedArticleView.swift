import SwiftUI

struct FeaturedArticleView: View {
    let article: Article
    var onBookmark: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url = article.thumbnailURL {
                RemoteImage(url: url, targetWidth: 420) {
                    heroPlaceholder
                }
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
            }

            HStack(alignment: .firstTextBaseline) {
                Text(article.category.uppercased())
                    .font(.miltonLabel)
                    .tracking(0.8)
                    .foregroundColor(Color.categoryColor(for: article.category))

                Spacer()

                Text(article.publishedDate.miltonRelative)
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
            }

            Text(article.title)
                .font(.miltonHeadline)
                .foregroundColor(.miltonText)
                .fixedSize(horizontal: false, vertical: true)

            if !article.summary.isEmpty {
                Text(article.summary)
                    .font(.miltonBody)
                    .foregroundColor(.miltonSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("By \(article.author)")
                        .fontWeight(.medium)
                        .foregroundColor(.miltonText)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Text("\(article.estimatedReadTime) min read")
                    }
                }

                Spacer(minLength: 8)

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
            .font(.miltonCaption)
            .foregroundColor(.miltonSecondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Featured: \(article.title), by \(article.author)")
    }

    private var heroPlaceholder: some View {
        ZStack {
            Color.miltonPrimary.opacity(0.1)
            Text("The Milton Paper")
                .font(.custom("OldEnglishTextMT", size: 34))
                .foregroundColor(.miltonPrimary.opacity(0.22))
        }
    }
}
