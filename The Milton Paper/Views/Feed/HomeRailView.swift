import SwiftUI

/// One card in a rail. Keeping this separate from `HomeModuleItem` lets the
/// rail render remote modules today and article packages again later without
/// knowing where its contents came from.
struct HomeRailItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let imageURL: URL?
    let destination: HomeModuleDestination
    var placeholderSymbol: String = "photo"

    init(id: String, title: String, subtitle: String?, imageURL: URL?,
         destination: HomeModuleDestination, placeholderSymbol: String = "photo") {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.destination = destination
        self.placeholderSymbol = placeholderSymbol
    }

    init(_ item: HomeModuleItem) {
        self.init(id: item.id, title: item.title, subtitle: item.subtitle,
                  imageURL: item.imageURL, destination: item.destination)
    }

    init(article: Article) {
        self.init(id: article.id, title: article.title, subtitle: "By \(article.author)",
                  imageURL: article.thumbnailURL, destination: .article(article.id),
                  placeholderSymbol: "text.quote")
    }
}

/// A compact, print-like horizontal rail. Sits inside the front page's gutter,
/// so it applies no horizontal padding of its own.
struct HomeRailView: View {
    let title: String
    let items: [HomeRailItem]
    var seeAllLabel: String = "View all"
    var onSeeAll: (() -> Void)?
    let onSelect: (HomeRailItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.miltonTitle)
                    .foregroundColor(.miltonText)
                Spacer()
                if let onSeeAll {
                    Button(action: onSeeAll) {
                        HStack(spacing: 3) {
                            Text(seeAllLabel)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .font(.miltonLabel)
                        .foregroundColor(.miltonPrimary)
                    }
                    .accessibilityLabel("\(seeAllLabel), \(title)")
                }
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(items) { item in
                        Button { onSelect(item) } label: {
                            HomeRailCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .disabled(item.destination == .none)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

private struct HomeRailCard: View {
    let item: HomeRailItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: item.imageURL, targetWidth: 270) {
                ZStack {
                    Color.miltonBackground
                    Image(systemName: item.placeholderSymbol)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.miltonSecondary.opacity(0.55))
                }
            }
            .frame(height: 112)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.miltonStoryTitle)
                    .foregroundColor(.miltonText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.miltonMeta)
                        .foregroundColor(.miltonSecondary)
                        .lineLimit(1)
                }
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
        .accessibilityLabel([item.title, item.subtitle].compactMap { $0 }.joined(separator: ", "))
    }
}
