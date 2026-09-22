import SwiftUI

enum TMPlayGame: String, CaseIterable, Identifiable {
    case wordle
    case connections

    var id: String { rawValue }
    var label: String { self == .wordle ? "Wordle" : "Connections" }

    static func validSelection(_ game: TMPlayGame, flags: FeatureFlags) -> TMPlayGame {
        game == .connections && !flags.showConnections ? .wordle : game
    }
}

/// The TMPlay tab shell. It owns only the picker; each game keeps its own
/// view model and header.
struct TMPlayView: View {
    @ObservedObject private var appConfiguration = AppConfiguration.shared
    @AppStorage("tmplay.lastGame") private var storedGame = TMPlayGame.wordle.rawValue
    @State private var game: TMPlayGame = .wordle

    // The games' state lives here, not in their views, so switching tabs does
    // not deallocate a half-finished board.
    @StateObject private var wordle = WordleViewModel()
    @StateObject private var connections = ConnectionsViewModel()

    private var showsPicker: Bool { appConfiguration.flags.showConnections }

    var body: some View {
        VStack(spacing: 0) {
            if showsPicker {
                Picker("Game", selection: $game) {
                    ForEach(TMPlayGame.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, MiltonLayout.gutter)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .accessibilityIdentifier("tmplay.game-picker")

                Divider()
            }

            // A paging TabView so the games can be swiped between as well as
            // picked. Both view models live above it, so a board in progress
            // survives either way of switching.
            TabView(selection: $game) {
                WordlePageView(viewModel: wordle)
                    .tag(TMPlayGame.wordle)
                if showsPicker {
                    ConnectionsPageView(viewModel: connections)
                        .tag(TMPlayGame.connections)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color.miltonBackground.ignoresSafeArea())
        .onAppear {
            // Test launches always open on Wordle so a previous run's stored
            // choice cannot change what a test sees.
            game = Config.isUITesting
                ? .wordle
                : TMPlayGame.validSelection(TMPlayGame(rawValue: storedGame) ?? .wordle,
                                            flags: appConfiguration.flags)
        }
        .onChange(of: game) { _, newValue in
            guard !Config.isUITesting else { return }
            storedGame = newValue.rawValue
        }
        .onChange(of: appConfiguration.flags.showConnections) { _, _ in
            game = TMPlayGame.validSelection(game, flags: appConfiguration.flags)
        }
    }
}
