import SwiftUI

struct ConnectionsPageView: View {
    @ObservedObject var viewModel: ConnectionsViewModel
    @ObservedObject private var service = ConnectionsService.shared
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHelp = false

    private let spacing: CGFloat = 8

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()

                if viewModel.puzzle == nil {
                    emptyState
                } else {
                    board
                }
            }

            if let message = viewModel.message {
                toast(message)
            }

            if viewModel.isFinished {
                ConnectionsResultCard(viewModel: viewModel)
            }

            if showHelp {
                ConnectionsHelpOverlay { showHelp = false }
            }
        }
        .task {
            await service.load()
            viewModel.adopt(service.livePuzzle)
            viewModel.cleanupStaleStates(keeping: service.knownPuzzleIDs)
        }
        .onChange(of: service.livePuzzle?.id) { _, _ in
            viewModel.adopt(service.livePuzzle)
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            // Balances the help button; Connections has no leaderboard.
            Color.clear.frame(width: 44, height: 44)

            Spacer()

            VStack(spacing: 2) {
                Text("Connections")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundColor(.miltonText)
                if let subtitle {
                    Text(subtitle)
                        .font(.miltonLabel)
                        .foregroundColor(.miltonSecondary)
                }
            }

            Spacer()

            Button { showHelp = true } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.miltonPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("How to play")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var subtitle: String? {
        if let title = viewModel.puzzle?.title { return title }
        if let author = viewModel.puzzle?.author { return author }
        guard let date = viewModel.puzzle?.startsAt else { return nil }
        return date.formatted(.dateTime.month(.wide).day())
    }

    private func toast(_ message: String) -> some View {
        VStack {
            Text(message)
                .font(.miltonCaption)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
                .padding(.top, 84)
            Spacer()
        }
        .allowsHitTesting(false)
        .accessibilityIdentifier("connections.toast")
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No puzzle yet")
                .font(.miltonTitle)
                .foregroundColor(.miltonText)
            Text("This week's Connections will appear here.")
                .font(.miltonMeta)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(MiltonLayout.gutter)
    }

    // MARK: - Board

    private var board: some View {
        GeometryReader { proxy in
            // 375 − 40 gutter = 335; (335 − 24) / 4 ≈ 78pt tiles. Capped so an
            // iPad does not render enormous squares.
            let boardWidth = min(proxy.size.width - MiltonLayout.gutter * 2, 420)
            let side = max(56, (boardWidth - spacing * 3) / 4)
            // Accessibility sizes get taller tiles rather than smaller text.
            let tileHeight = side * (typeSize.isAccessibilitySize ? 1.45 : 1.0)

            ScrollView {
                VStack(spacing: spacing) {
                    ForEach(viewModel.solved) { group in
                        SolvedGroupBand(group: group, height: tileHeight)
                    }

                    ForEach(Array(rows(of: viewModel.tiles).enumerated()), id: \.offset) { _, row in
                        HStack(spacing: spacing) {
                            ForEach(row, id: \.self) { word in
                                ConnectionsTileView(
                                    word: word,
                                    isSelected: viewModel.selection.contains(word),
                                    side: side,
                                    height: tileHeight
                                ) {
                                    viewModel.toggle(word)
                                }
                            }
                        }
                        .modifier(ShakeEffect(token: viewModel.shakeToken, enabled: !reduceMotion))
                    }

                    if !viewModel.isFinished {
                        MistakeDots(remaining: viewModel.mistakesRemaining)
                            .padding(.top, 10)
                        controls
                    }
                }
                .frame(width: boardWidth)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button("Shuffle") { viewModel.shuffle() }
                .buttonStyle(ConnectionsControlStyle(isProminent: false))
            Button("Deselect all") { viewModel.deselectAll() }
                .buttonStyle(ConnectionsControlStyle(isProminent: false))
                .disabled(viewModel.selection.isEmpty)
            Button("Submit") { viewModel.submit() }
                .buttonStyle(ConnectionsControlStyle(isProminent: true))
                .disabled(!viewModel.canSubmit)
        }
        .padding(.top, 6)
    }

    private func rows(of words: [String]) -> [[String]] {
        stride(from: 0, to: words.count, by: 4).map {
            Array(words[$0..<min($0 + 4, words.count)])
        }
    }
}

// MARK: - Pieces

struct ConnectionsTileView: View {
    let word: String
    let isSelected: Bool
    let side: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(word)
                .font(.system(size: 15, weight: .semibold))
                .minimumScaleFactor(0.55)
                .lineLimit(2)
                .allowsTightening(true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .frame(width: side, height: height)
                .background(isSelected ? Color.miltonPrimary : TMPlayPalette.tileIdle)
                .foregroundColor(isSelected ? .white : .miltonText)
                .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("connections.tile.\(word)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct SolvedGroupBand: View {
    let group: ConnectionsGroup
    let height: CGFloat

    var body: some View {
        VStack(spacing: 3) {
            Text(group.name.uppercased())
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(.miltonText)
            Text(group.words.joined(separator: ", "))
                .font(.system(size: 13))
                .foregroundColor(.miltonText.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(TMPlayPalette.level(group.level))
        .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("connections.solved.\(group.id)")
    }
}

struct MistakeDots: View {
    let remaining: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("Mistakes remaining")
                .font(.miltonMeta)
                .foregroundColor(.miltonSecondary)
            ForEach(0..<ConnectionsViewModel.maxMistakes, id: \.self) { index in
                Circle()
                    .fill(index < remaining ? Color.miltonText : Color.miltonRule)
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(remaining) mistakes remaining")
    }
}

struct ConnectionsControlStyle: ButtonStyle {
    let isProminent: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.miltonCaption.weight(.semibold))
            .foregroundColor(isProminent ? .white : .miltonText)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(isProminent ? Color.miltonPrimary : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isProminent ? Color.clear : Color.miltonRule, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.35)
    }
}

/// Nudges the row sideways on a wrong guess. Skipped under reduce motion,
/// where the toast carries the message instead.
struct ShakeEffect: ViewModifier {
    let token: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: 0)
            .animation(.default, value: token)
            .modifier(ShakeOffset(animatableData: enabled ? CGFloat(token) : 0))
    }
}

private struct ShakeOffset: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let travel = 8 * sin(animatableData * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: travel, y: 0))
    }
}

struct ConnectionsResultCard: View {
    @ObservedObject var viewModel: ConnectionsViewModel

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            VStack(spacing: 10) {
                Text(viewModel.phase == .won ? "Brilliant!" : "Next time")
                    .font(.miltonSectionTitle)
                    .foregroundColor(.miltonText)
                Text(viewModel.phase == .won
                     ? "You found all four groups."
                     : "The groups are revealed above.")
                    .font(.miltonMeta)
                    .foregroundColor(.miltonSecondary)
                    .multilineTextAlignment(.center)
                Text("A new puzzle arrives next week.")
                    .font(.miltonMeta)
                    .foregroundColor(.miltonSecondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .miltonCardStyle()
            .padding(.horizontal, MiltonLayout.gutter)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("connections.result")
    }
}

struct ConnectionsHelpOverlay: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("How to play")
                        .font(.miltonSectionTitle)
                        .foregroundColor(.miltonText)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.miltonSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                }

                Text("Find four groups of four words that share something.")
                    .font(.miltonBody)
                    .foregroundColor(.miltonText)
                Text("Select four tiles and tap Submit. You get four mistakes. Solving a group tells you how hard it was, from straw (easiest) to lilac (trickiest). Three of four right shows “One away”.")
                    .font(.miltonMeta)
                    .foregroundColor(.miltonSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    ForEach(1...4, id: \.self) { level in
                        RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous)
                            .fill(TMPlayPalette.level(level))
                            .frame(height: 18)
                    }
                }

                Text("Connections is inspired by Connections by The New York Times.")
                    .font(.miltonLabel)
                    .foregroundColor(.miltonSecondary)
                    .padding(.top, 4)
            }
            .padding(20)
            .miltonCardStyle()
            .padding(.horizontal, MiltonLayout.gutter)
        }
    }
}
