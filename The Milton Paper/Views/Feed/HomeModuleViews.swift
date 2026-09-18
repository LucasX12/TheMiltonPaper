import SwiftUI

/// A remotely-configured feature box. Deliberately a step quieter than
/// `LeadStoryView` — it reads as a labelled package next to the journalism
/// rather than competing with the lead story for the front page.
struct HomeSpotlightCard: View {
    let module: HomeModule
    let onOpen: (HomeModuleDestination) -> Void

    var body: some View {
        Button { onOpen(module.destination) } label: {
            VStack(alignment: .leading, spacing: 10) {
                if let subtitle = module.subtitle {
                    Text(subtitle.uppercased())
                        .font(.miltonEyebrow)
                        .tracking(0.7)
                        .foregroundColor(.miltonSecondary)
                }

                if let imageURL = module.imageURL {
                    RemoteImage(url: imageURL, targetWidth: 760) {
                        Rectangle().fill(Color.miltonRule.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
                }

                Text(module.title)
                    .font(.miltonSectionTitle)
                    .foregroundColor(.miltonText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let body = module.body {
                    Text(body)
                        .font(.miltonBody)
                        .foregroundColor(.miltonSecondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if module.destination != .none {
                    HStack(spacing: 6) {
                        Text(module.resolvedActionLabel)
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.miltonCaption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.miltonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(module.destination == .none)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.module.\(module.id)")
    }
}

/// Renders a placement's worth of modules, separators included, and collapses
/// to nothing at all when there are none — no stray rule, no stray spacing.
struct HomeModulesSection: View {
    let modules: [HomeModule]
    let onOpen: (HomeModuleDestination) -> Void

    var body: some View {
        if !modules.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(modules) { module in
                    EditorialRule().padding(.vertical, 20)

                    switch module.kind {
                    case .spotlight:
                        HomeSpotlightCard(module: module, onOpen: onOpen)
                    case .rail:
                        HomeRailView(
                            title: module.title,
                            items: module.renderableItems.map(HomeRailItem.init),
                            onSelect: { onOpen($0.destination) }
                        )
                        .accessibilityIdentifier("home.module.\(module.id)")
                    }
                }
            }
        }
    }
}

/// `URL` isn't `Identifiable`, so navigation destinations that carry one need
/// this wrapper.
struct IdentifiedURL: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
}
