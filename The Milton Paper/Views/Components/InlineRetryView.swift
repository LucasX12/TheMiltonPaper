import SwiftUI

struct InlineRetryView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(message).font(.miltonCaption).foregroundStyle(Color.miltonSecondary)
            Spacer(minLength: 0)
            Button("Retry", action: retry)
                .font(.miltonCaption)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.vertical, 8)
    }
}
