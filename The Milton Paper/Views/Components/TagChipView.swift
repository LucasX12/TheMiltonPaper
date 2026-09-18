import SwiftUI

struct TagChipView: View {
    let label: String
    var color: Color = .miltonPrimary

    var body: some View {
        Text(label.uppercased())
            .font(.miltonLabel)
            .tracking(0.8)
            .foregroundColor(color)
    }
}

extension TagChipView {
    init(category: String) {
        self.init(label: category, color: Color.categoryColor(for: category))
    }
}
