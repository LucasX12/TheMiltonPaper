import SwiftUI
import UIKit

enum MiltonLayout {
    /// A restrained radius that softens edges without turning surfaces into pills.
    static let cornerRadius: CGFloat = 4
    static let gutter: CGFloat = 20
    static let readableWidth: CGFloat = 760
}

// Pulsing shimmer used as the loading placeholder for all AsyncImages
struct ShimmerView: View {
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Color.miltonSecondary
            .opacity(animating ? 0.18 : 0.07)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: animating)
            .onAppear { animating = !reduceMotion }
            .accessibilityHidden(true)
    }
}

struct EditorialRule: View {
    @Environment(\.displayScale) private var displayScale
    var body: some View {
        Rectangle()
            .fill(Color.miltonRule)
            .frame(height: 1 / displayScale)
    }
}

extension View {
    func miltonCardStyle() -> some View {
        self
            .background(Color.miltonSurface)
            .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous)
                    .stroke(Color.miltonRule, lineWidth: 1)
            }
    }

    func editorialReadableColumn() -> some View {
        frame(maxWidth: MiltonLayout.readableWidth)
            .frame(maxWidth: .infinity)
    }

    func miltonPrimaryButton() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.miltonPrimary)
            .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
    }

    func miltonSecondaryButton() -> some View {
        self
            .font(.headline)
            .foregroundColor(Color.miltonPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous)
                    .stroke(Color.miltonPrimary, lineWidth: 1)
            )
    }
}
