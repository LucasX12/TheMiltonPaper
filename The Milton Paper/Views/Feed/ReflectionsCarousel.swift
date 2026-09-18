import SwiftUI

/// A compact, print-like rail for the temporary Student Reflections package.
struct ReflectionsCarousel: View {
    let articles: [Article]
    let onSelect: (Article) -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Student Reflections")
                    .font(.miltonTitle)
                    .foregroundColor(.miltonText)
                Spacer()
                Button(action: onSeeAll) {
                    HStack(spacing: 3) {
                        Text("View all")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(.miltonLabel)
                    .foregroundColor(.miltonPrimary)
                }
                .accessibilityLabel("See all student reflections")
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(articles) { article in
                        Button { onSelect(article) } label: {
                            ReflectionCard(article: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            // The feed locks the page pager while a horizontal drag starts
            // here; that lock propagates down the environment, so this scroll
            // view must explicitly stay enabled.
            .scrollDisabled(false)
        }
    }
}

private struct ReflectionCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: article.thumbnailURL, targetWidth: 270) {
                ZStack {
                    Color.miltonBackground
                    Image(systemName: "text.quote")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.miltonSecondary.opacity(0.55))
                }
            }
            .frame(height: 112)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.miltonStoryTitle)
                    .foregroundColor(.miltonText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("By \(article.author)")
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(width: 250, height: 190, alignment: .top)
        .background(Color.miltonSurface)
        .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous)
                .stroke(Color.miltonRule, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reflection: \(article.title), by \(article.author)")
    }
}
