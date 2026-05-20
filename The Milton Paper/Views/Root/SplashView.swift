import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.92

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text("The Milton Paper")
                        .font(.custom("OldEnglishTextMT", size: 44))
                        .foregroundColor(.miltonPrimary)

                    Rectangle()
                        .fill(Color.miltonAccent)
                        .frame(height: 2)
                        .padding(.horizontal, 40)

                    Text("EST. 1983")
                        .font(.miltonLabel)
                        .foregroundColor(.miltonSecondary)
                        .tracking(4)
                }
            }
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) {
                    opacity = 1
                    scale = 1
                }
            }
        }
    }
}
