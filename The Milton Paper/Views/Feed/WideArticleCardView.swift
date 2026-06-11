import SwiftUI

struct WideArticleCardView: View {
    let article: Article
    var onBookmark: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-width hero image
            ZStack(alignment: .bottomLeading) {
                if let url = article.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholder
                        default:
                            ShimmerView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipped()
                } else {
                    placeholder
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                TagChipView(category: article.category, style: .solid)
                    .padding(12)
            }

            // Text section
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(.custom("Georgia", size: 18).weight(.semibold))
                    .foregroundColor(.miltonText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.miltonBody)
                        .foregroundColor(.miltonSecondary)
                        .lineLimit(2)
                }

                HStack {
                    HStack(spacing: 4) {
                        Text("By \(article.author)")
                        Text("·")
                        Text(article.publishedDate.miltonRelative)
                    }
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)

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
            }
            .padding(14)
        }
        .miltonCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Article: \(article.title), by \(article.author)")
    }

    private var placeholder: some View {
        ZStack {
            Color.miltonPrimary.opacity(0.1)
            Image(systemName: "newspaper.fill")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundColor(.miltonPrimary.opacity(0.2))
        }
    }
}
