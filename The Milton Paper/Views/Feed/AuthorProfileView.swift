import SwiftUI

struct AuthorProfileView: View {
    let author: String

    @ObservedObject private var directory = WriterDirectoryService.shared

    private var writer: Writer? { directory.writer(named: author) }
    @State private var articles: [Article] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            if isLoading {
                LoadingView()
            } else if articles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 44))
                        .foregroundColor(.miltonSecondary.opacity(0.4))
                    Text("No articles found")
                        .font(.miltonTitle)
                        .foregroundColor(.miltonSecondary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Author header
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 16) {
                                AuthorAvatarView(name: author, size: 56)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(author)
                                        .font(.miltonTitle)
                                        .foregroundColor(.miltonText)
                                    if let credit = writer?.credit {
                                        Text(credit)
                                            .font(.miltonMeta)
                                            .foregroundColor(.miltonSecondary)
                                    }
                                    Text("\(articles.count) article\(articles.count == 1 ? "" : "s")")
                                        .font(.miltonMeta)
                                        .foregroundColor(.miltonSecondary)
                                }
                            }

                            if let bio = writer?.bio {
                                Text(bio)
                                    .font(.miltonBody)
                                    .foregroundColor(.miltonSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(24)

                        Divider()

                        LazyVStack(spacing: 0) {
                            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                                NavigationLink {
                                    ArticleDetailView(article: article)
                                } label: {
                                    ArticleCardView(article: article, onBookmark: nil)
                                }
                                .buttonStyle(.plain)

                                if index < articles.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 24)
                    }
                }
            }
        }
        .navigationTitle(author)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let all = try? await ArticleService.shared.fetchArticles() {
                articles = all
                    .filter { $0.author.components(separatedBy: " and ").contains(author) }
                    .sorted { $0.publishedDate > $1.publishedDate }
            }
            isLoading = false
        }
    }
}
