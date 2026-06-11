import SwiftUI

// Pulsing shimmer used as the loading placeholder for all AsyncImages
struct ShimmerView: View {
    @State private var animating = false
    var body: some View {
        Color.miltonSecondary
            .opacity(animating ? 0.18 : 0.07)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: animating)
            .onAppear { animating = true }
    }
}

extension View {
    func miltonCardStyle() -> some View {
        self
            .background(Color.miltonSurface)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    func miltonPrimaryButton() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.miltonPrimary)
            .cornerRadius(10)
    }

    func miltonSecondaryButton() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color.miltonPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.miltonPrimary, lineWidth: 1.5)
            )
    }
}
