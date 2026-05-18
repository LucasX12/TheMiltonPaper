import SwiftUI

struct EditorialArticleCardView: View {
    let article: Article
    var onBookmark: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent stripe
            Rectangle()
                .fill(Color.categoryColor(for: article.category))
                .frame(maxWidth: .infinity)
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    TagChipView(category: article.category)
                    Spacer()
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

                Text(article.title)
                    .font(.custom("Georgia", size: 20).weight(.bold))
                    .foregroundColor(.miltonText)
                    .fixedSize(horizontal: false, vertical: true)

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.miltonSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                    .background(Color.miltonSecondary.opacity(0.2))

                HStack(spacing: 4) {
                    Text("By \(article.author)")
                        .fontWeight(.medium)
                    Text("·")
                    Text(article.publishedDate.miltonRelative)
                    Text("·")
                    Text("\(article.estimatedReadTime) min read")
                }
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
            }
            .padding(16)
        }
        .miltonCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Article: \(article.title), by \(article.author)")
    }
}
