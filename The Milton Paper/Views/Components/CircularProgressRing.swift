import SwiftUI

struct CircularProgressRing: View {
    let progress: Double
    var size: CGFloat = 22
    var lineWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.miltonSecondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0, progress))))
                .stroke(Color.miltonPrimary,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if progress >= 0.99 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.miltonPrimary)
            }
        }
        // Inset the circles so the stroke doesn't bleed past the frame boundary
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
        .animation(.linear(duration: 0.1), value: progress)
    }
}
