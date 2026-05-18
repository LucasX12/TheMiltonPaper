import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.92

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 52, weight: .light))
                    .foregroundColor(.miltonPrimary)

                VStack(spacing: 6) {
                    Text("THE MILTON PAPER")
                        .font(.custom("Georgia", size: 26).weight(.bold))
                        .foregroundColor(.miltonPrimary)
                        .tracking(3)

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
