import SwiftUI

/// The standing note that the app itself was built with AI while its
/// journalism is not. Wording and the policy link both come from Remote
/// Config, so they change without a release.
struct AINoticeView: View {
    @ObservedObject private var appConfiguration = AppConfiguration.shared
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(appConfiguration.notices.aiNotice)
                .font(.miltonMeta)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)

            // A malformed address reads as plain text rather than a dead link.
            if let url = appConfiguration.notices.aiPolicyURL {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Text(appConfiguration.notices.aiPolicyLabel)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.miltonMeta.weight(.semibold))
                    .foregroundColor(.miltonPrimary)
                }
                .frame(minHeight: 44, alignment: alignment == .center ? .center : .leading)
                .accessibilityIdentifier("ai.policy.link")
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .accessibilityIdentifier("ai.notice")
    }
}
