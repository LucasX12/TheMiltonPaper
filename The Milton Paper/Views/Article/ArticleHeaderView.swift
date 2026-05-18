import SwiftUI

struct ArticleHeaderView: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hero image
            if let url = article.thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        heroPlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipped()
            } else {
                heroPlaceholder
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            }

            VStack(alignment: .leading, spacing: 12) {
                TagChipView(category: article.category)

                Text(article.title)
                    .font(.miltonHeadline)
                    .foregroundColor(.miltonText)
                    .fixedSize(horizontal: false, vertical: true)

                // Byline
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("By \(article.author)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.miltonText)
                        HStack(spacing: 6) {
                            Text(article.publishedDate.miltonFormatted)
                            Text("·")
                            Text("\(article.estimatedReadTime) min read")
                        }
                        .font(.miltonCaption)
                        .foregroundColor(.miltonSecondary)
                    }
                }

                Divider()
                    .background(Color.miltonSecondary.opacity(0.2))
            }
            .padding(.horizontal, 36)
        }
    }

    private var heroPlaceholder: some View {
        ZStack {
            Color.miltonPrimary.opacity(0.08)
            Image(systemName: "newspaper.fill")
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundColor(.miltonPrimary.opacity(0.2))
        }
    }
}
