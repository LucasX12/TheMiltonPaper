import SwiftUI

struct LoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.miltonPrimary)
            Text(message)
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.miltonBackground)
    }
}
