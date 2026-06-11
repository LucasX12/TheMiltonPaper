import SwiftUI

/// Horizontal snap carousel of Student Reflections shown at the top of the
/// Recent tab. Temporary, like the section itself — it disappears on its own
/// once the feed stops returning articles.
struct ReflectionsCarousel: View {
    let articles: [Article]
    let onSelect: (Article) -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Student Reflections")
                    .font(.miltonLabel)
                    .foregroundColor(.miltonSecondary)
                Spacer()
                Button(action: onSeeAll) {
                    HStack(spacing: 3) {
                        Text("See All")
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
                LazyHStack(spacing: 12) {
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
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: article.thumbnailURL, targetWidth: 270) {
                ZStack {
                    Color.miltonPrimary.opacity(0.15)
                    Image(systemName: "text.quote")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundColor(.miltonPrimary.opacity(0.35))
                }
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.custom("Georgia", size: 16).weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("By \(article.author)")
                    .font(.miltonCaption)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(width: 270, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reflection: \(article.title), by \(article.author)")
    }
}
