import SwiftUI

struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.miltonAccent)

            Text("Something went wrong")
                .font(.miltonTitle)
                .foregroundColor(.miltonText)

            Text(message)
                .font(.miltonBody)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let retry = retryAction {
                Button("Try Again", action: retry)
                    .miltonPrimaryButton()
                    .padding(.horizontal, 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.miltonBackground)
    }
}
