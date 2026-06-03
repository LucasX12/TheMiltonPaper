import SwiftUI
import UIKit

private let kArticleHorizontalPadding: CGFloat = 24

struct ArticleHeaderView: View {
    let article: Article
    var width: CGFloat = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 393

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
                    .onTapGesture {
                        NotificationCenter.default.post(
                            name: .miltonNavigateToCategory,
                            object: nil,
                            userInfo: ["category": article.category]
                        )
                    }

                Text(article.title)
                    .font(.miltonHeadline)
                    .foregroundColor(.miltonText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Byline
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        bylineView(for: article.author)
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
            .padding(.horizontal, kArticleHorizontalPadding)
        }
        .frame(width: width, alignment: .leading)
    }

    @ViewBuilder
    private func bylineView(for authorString: String) -> some View {
        let authors = authorString.components(separatedBy: " and ")
        HStack(spacing: 0) {
            Text("By ")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.miltonText)
            ForEach(authors.indices, id: \.self) { i in
                NavigationLink {
                    AuthorProfileView(author: authors[i])
                } label: {
                    Text(authors[i])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.miltonPrimary)
                }
                .buttonStyle(.plain)
                if i < authors.count - 1 {
                    Text(" and ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.miltonText)
                }
            }
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
