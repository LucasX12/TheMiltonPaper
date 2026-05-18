import SwiftUI

struct CategoryFilterView: View {
    let categories: [String]
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selected = category
                        }
                    } label: {
                        Text(category)
                            .font(.system(size: 14, weight: selected == category ? .semibold : .regular))
                            .foregroundColor(selected == category ? .white : .miltonText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selected == category ? Color.miltonPrimary : Color.miltonSurface)
                                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                            )
                    }
                    .accessibilityLabel("\(category) category filter")
                    .accessibilityAddTraits(selected == category ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}
