import SwiftUI

struct TagChipView: View {
    let label: String
    var color: Color = .miltonPrimary
    var style: TagChipStyle = .filled

    enum TagChipStyle { case filled, solid }

    var body: some View {
        Text(label.uppercased())
            .font(.miltonLabel)
            .foregroundColor(style == .filled ? color : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(style == .filled ? color.opacity(0.12) : color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(style == .filled ? 0.3 : 0), lineWidth: 1)
            )
    }
}

extension TagChipView {
    init(category: String, style: TagChipStyle = .filled) {
        self.init(label: category, color: Color.categoryColor(for: category), style: style)
    }
}
