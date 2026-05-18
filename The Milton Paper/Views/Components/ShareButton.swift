import SwiftUI

struct ShareButton: View {
    let article: Article

    var body: some View {
        ShareLink(
            item: article.articleURL,
            subject: Text(article.title),
            message: Text("Check out this article from The Milton Paper")
        ) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.miltonPrimary)
        }
        .accessibilityLabel("Share article")
    }
}
