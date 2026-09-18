import SwiftUI

struct LeadStoryView: View {
    let article: Article
    var onBookmark: (() -> Void)?
    var showsCategory = true
    var onSelect: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            EditorialStoryAction(article: article, action: onSelect) {
                VStack(alignment: .leading, spacing: 11) {
            if let url = article.thumbnailURL {
                RemoteImage(url: url, targetWidth: 760) {
                    storyImagePlaceholder
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
            }

            if showsCategory { EditorialCategoryLabel(category: article.category) }

            Text(article.title)
                .font(.miltonHeadline)
                .foregroundColor(.miltonText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !article.summary.isEmpty {
                Text(article.summary)
                    .font(.miltonBody)
                    .foregroundColor(.miltonSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

                }
            }
            StoryMetadataView(article: article, onBookmark: onBookmark)
        }
        .contentShape(Rectangle())
    }

    private var storyImagePlaceholder: some View {
        Rectangle()
            .fill(Color.miltonRule.opacity(0.5))
            .overlay {
                Text("The Milton Paper")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundColor(.miltonSecondary.opacity(0.55))
            }
    }
}

struct SecondaryStoryView: View {
    let article: Article
    var onBookmark: (() -> Void)?
    var showsCategory = true
    var compact = false
    var onSelect: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
          EditorialStoryAction(article: article, action: onSelect) {
           HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                if showsCategory { EditorialCategoryLabel(category: article.category) }

                Text(article.title)
                    .font(compact ? .miltonStoryTitle : .miltonTitle)
                    .foregroundColor(.miltonText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !dynamicTypeSize.isAccessibilitySize, let url = article.thumbnailURL {
                RemoteImage(url: url, targetWidth: 140) {
                    Color.miltonRule.opacity(0.5)
                }
                .frame(width: compact ? 88 : 112, height: compact ? 66 : 84)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
            }
           }
          }
          StoryMetadataView(article: article, onBookmark: onBookmark, compact: true)
        }
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }
}

struct EditorialCategoryLabel: View {
    let category: String

    var body: some View {
        Text(category.uppercased())
            .font(.miltonEyebrow)
            .tracking(0.7)
            .foregroundColor(.miltonSecondary)
    }
}

struct StoryMetadataView: View {
    let article: Article
    var onBookmark: (() -> Void)?
    var compact = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                if !dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: 5) {
                        Text("By \(article.author)")
                        Text("·")
                        dateAndReadTime
                    }.fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("By \(article.author)")
                    dateAndReadTime
                }
            }

            Spacer(minLength: 4)

            if let onBookmark {
                Button(action: onBookmark) {
                    Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(article.isBookmarked ? .miltonPrimary : .miltonSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(article.isBookmarked ? "Remove bookmark" : "Save story")
            }
        }
        .font(.miltonMeta)
        .foregroundColor(.miltonSecondary)
    }

    private var dateAndReadTime: some View {
        Text(compact ? article.publishedDate.miltonRelative :
            "\(article.publishedDate.miltonRelative) · \(article.estimatedReadTime) min read")
    }
}

/// Story navigation and Save are separate controls, not nested tap gestures.
struct EditorialStoryAction<Content: View>: View {
    let article: Article
    let action: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        if let action {
            Button(action: action) { content().frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }
                .buttonStyle(EditorialPressStyle())
                .accessibilityLabel(article.title)
                .accessibilityHint("Read story")
                .accessibilityIdentifier("story.\(article.id)")
        } else {
            content()
        }
    }
}

struct EditorialPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .hoverEffect(.highlight)
    }
}

struct EditorialFeedSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ShimmerView()
                    .frame(height: 210)
                skeletonLine(width: 90, height: 10)
                skeletonLine(width: nil, height: 24)
                skeletonLine(width: 260, height: 24)
                skeletonLine(width: nil, height: 14)
                EditorialRule().padding(.vertical, 10)
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            skeletonLine(width: 80, height: 9)
                            skeletonLine(width: nil, height: 18)
                            skeletonLine(width: 220, height: 18)
                        }
                        ShimmerView().frame(width: 100, height: 76)
                    }
                    EditorialRule()
                }
            }
            .padding(MiltonLayout.gutter)
            .editorialReadableColumn()
        }
        .background(Color.miltonBackground)
        .accessibilityLabel("Loading stories")
    }

    private func skeletonLine(width: CGFloat?, height: CGFloat) -> some View {
        ShimmerView()
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(width: width, height: height)
    }
}
