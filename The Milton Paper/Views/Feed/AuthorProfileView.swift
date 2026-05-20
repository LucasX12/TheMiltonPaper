import SwiftUI

struct AuthorProfileView: View {
    let author: String
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
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.miltonPrimary)
                                    .frame(width: 56, height: 56)
                                Text(author.prefix(1).uppercased())
                                    .font(.custom("Georgia", size: 22).weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(author)
                                    .font(.miltonTitle)
                                    .foregroundColor(.miltonText)
                                Text("\(articles.count) article\(articles.count == 1 ? "" : "s")")
                                    .font(.miltonCaption)
                                    .foregroundColor(.miltonSecondary)
                            }
                        }
                        .padding(24)

                        Divider()

                        LazyVStack(spacing: 12) {
                            ForEach(articles) { article in
                                NavigationLink {
                                    ArticleDetailView(article: article)
                                } label: {
                                    ArticleCardView(article: article, onBookmark: nil)
                                        .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 12)

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
