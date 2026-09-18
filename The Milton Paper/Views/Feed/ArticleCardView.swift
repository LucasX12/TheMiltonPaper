import SwiftUI

struct ArticleCardView: View {
    let article: Article
    var onBookmark: (() -> Void)?
    var showsCategory = true
    var onSelect: (() -> Void)?

    var body: some View {
        SecondaryStoryView(article: article, onBookmark: onBookmark,
                           showsCategory: showsCategory, compact: true, onSelect: onSelect)
    }
}
