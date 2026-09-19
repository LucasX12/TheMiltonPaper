import SwiftUI
import UIKit

struct ArticleHeaderView: View {
    let article: Article
    var width: CGFloat = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 393

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Button {
                        NotificationCenter.default.post(
                            name: .miltonNavigateToCategory,
                            object: nil,
                            userInfo: ["category": article.category]
                        )
                    } label: {
                        EditorialCategoryLabel(category: article.category)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 8)

                    Text("\(article.publishedDate.miltonFormatted) · \(article.estimatedReadTime) min read")
                        .font(.miltonMeta)
                        .foregroundColor(.miltonSecondary)
                }

                Text(article.title)
                    .font(.miltonHeadline)
                    .foregroundColor(.miltonText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let standfirst = article.standfirst {
                    Text(standfirst)
                        .font(.system(.title3, design: .serif))
                        .foregroundColor(.miltonSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if article.hasNamedAuthor {
                    bylineView(for: article.author)
                }
            }
            .padding(.horizontal, MiltonLayout.gutter)
            .padding(.top, 22)
            .padding(.bottom, 18)

            if let url = article.thumbnailURL {
                RemoteImage(url: url, targetWidth: width) { heroPlaceholder }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipped()
            }
        }
        .frame(width: width, alignment: .leading)
    }

    @ViewBuilder
    private func bylineView(for authorString: String) -> some View {
        let authors = authorString.components(separatedBy: " and ")
        VStack(alignment: .leading, spacing: 0) {
            ForEach(authors.indices, id: \.self) { index in
                NavigationLink {
                    AuthorProfileView(author: authors[index])
                } label: {
                    Text("\(index == 0 ? "By " : "and ")\(authors[index])")
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.miltonMeta.weight(.semibold))
        .foregroundColor(.miltonText)
    }

    private var heroPlaceholder: some View {
        Rectangle()
            .fill(Color.miltonRule.opacity(0.55))
            .overlay {
                Text("The Milton Paper")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundColor(.miltonSecondary.opacity(0.6))
            }
    }
}
