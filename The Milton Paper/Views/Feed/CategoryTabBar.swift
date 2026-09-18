import SwiftUI

struct CategoryTabBar: View {
    let categories: [String]
    @Binding var selection: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selection = category
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Text(category)
                                    .font(.system(size: 14, weight: selection == category ? .semibold : .regular))
                                    .foregroundColor(selection == category ? .miltonPrimary : .miltonSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                Rectangle()
                                    .fill(selection == category ? Color.miltonPrimary : Color.clear)
                                    .frame(height: 2)
                                    .animation(.easeInOut(duration: 0.25), value: selection)
                            }
                        }
                        .id(category)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: selection) { _, newSelection in
                withAnimation(.easeInOut(duration: 0.2)) {
                    // nil anchor scrolls just enough to reveal the selected tab,
                    // so the bar stays left-aligned instead of auto-centering
                    proxy.scrollTo(newSelection, anchor: nil)
                }
            }
        }
        .background(Color.miltonBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.miltonSecondary.opacity(0.15))
                .frame(height: 1)
        }
    }
}
