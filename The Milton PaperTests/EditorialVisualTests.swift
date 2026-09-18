import SwiftUI
import XCTest
@testable import The_Milton_Paper

/// Attachments are review artifacts, not pixel baselines. They exercise the
/// actual story components at the requested widths and text sizes.
@MainActor
final class EditorialVisualTests: XCTestCase {
    func testStoryLayoutSizeMatrix() throws {
        let sizes: [(String, CGSize)] = [
            ("iPhone-375", CGSize(width: 375, height: 812)),
            ("iPhone-393", CGSize(width: 393, height: 852)),
            ("iPhone-430", CGSize(width: 430, height: 932)),
            ("iPad-portrait", CGSize(width: 834, height: 1194)),
            ("iPad-landscape", CGSize(width: 1194, height: 834)),
        ]
        let textSizes: [(String, DynamicTypeSize)] = [
            ("default", .large), ("extra-large", .xLarge), ("accessibility", .accessibility3),
        ]
        for (device, size) in sizes {
            for (textLabel, textSize) in textSizes {
                let content = EditorialVisualFixture()
                    .environment(\.dynamicTypeSize, textSize)
                    .environment(\.horizontalSizeClass, size.width >= 768 ? .regular : .compact)
                    .environment(\.colorScheme, .light)
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .background(Color.white)
                    .clipped()
                let renderer = ImageRenderer(content: content)
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size.width, size.width)
                XCTAssertEqual(image.size.height, size.height)
                let attachment = XCTAttachment(image: image)
                attachment.name = "\(device)-\(textLabel)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}

private struct EditorialVisualFixture: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 3) {
                Text("The Milton Paper")
                    .font(.custom("OldEnglishTextMT", size: 30, relativeTo: .title))
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.custom("Georgia", size: 13, relativeTo: .footnote))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            EditorialRule().padding(.bottom, 16)
            LeadStoryView(article: MockData.articles[0], onBookmark: {})
            EditorialRule().padding(.top, 20)
            if sizeClass == .regular && !typeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 22) {
                    SecondaryStoryView(article: MockData.articles[1], onBookmark: {})
                    SecondaryStoryView(article: MockData.articles[2], onBookmark: {})
                }
            } else {
                SecondaryStoryView(article: MockData.articles[1], onBookmark: {})
                EditorialRule()
                ArticleCardView(article: MockData.articles[2], onBookmark: {})
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MiltonLayout.gutter)
        .editorialReadableColumn()
    }
}
