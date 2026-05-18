import SwiftUI

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
