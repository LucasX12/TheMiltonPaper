import SwiftUI

struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.miltonAccent)

            Text("We couldn't load the paper")
                .font(.miltonTitle)
                .foregroundColor(.miltonText)

            Text(message)
                .font(.miltonBody)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let retry = retryAction {
                Button(action: retry) {
                    Text("Try Again")
                        .miltonPrimaryButton()
                }
                .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.miltonBackground)
    }
}
