import SwiftUI

struct CategoryTabBar: View {
    let categories: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(categories.indices, id: \.self) { index in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedIndex = index
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Text(categories[index])
                                    .font(.system(size: 14, weight: selectedIndex == index ? .semibold : .regular))
                                    .foregroundColor(selectedIndex == index ? .miltonPrimary : .miltonSecondary)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 12)

                                Rectangle()
                                    .fill(selectedIndex == index ? Color.miltonPrimary : Color.clear)
                                    .frame(height: 2)
                                    .animation(.easeInOut(duration: 0.25), value: selectedIndex)
                            }
                        }
                        .id(index)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .background(Color.miltonSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.miltonSecondary.opacity(0.15))
                .frame(height: 1)
        }
    }
}
